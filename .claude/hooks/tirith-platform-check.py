#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "py-tirith @ git+https://github.com/StackGuardian/tirith.git@1.2.1",
# ]
# ///
"""Claude Code Stop hook: run the org's Tirith policies on StackGuardian (`tirith platform check`).

When Claude finishes a turn in which the Terraform/OpenTofu inputs changed, this runs a real
`tofu plan`, uploads it to the workflow below and blocks the stop on FAIL/WARN results so Claude
fixes them. The policies themselves live in StackGuardian, not in this repo.

Needs SG_API_TOKEN, AWS credentials and a terraform.tfvars with vpc_id / public_subnet_id.
Run by hand: .claude/hooks/tirith-platform-check.py --force
"""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", Path(__file__).resolve().parents[2]))
STATE_FILE = PROJECT_DIR / ".claude" / "tirith-platform.state"
SKIP_DIRS = {".terraform", ".claude", ".git"}
INPUT_GLOBS = ("*.tf", "*.tfvars", "*.tftpl")

SG_ORG = os.environ.get("TIRITH_SG_ORG") or os.environ.get("SG_ORG") or "wicked-hop"
WF_GROUP = os.environ.get("TIRITH_WF_GROUP", "adis")
WF_ID = os.environ.get("TIRITH_WF_ID", "simple-ec2-tirith")
TIRITH = Path(sys.executable).parent / "tirith"


def inputs():
  files = {p for g in INPUT_GLOBS for p in PROJECT_DIR.rglob(g)}
  return sorted(p for p in files if not SKIP_DIRS & set(p.relative_to(PROJECT_DIR).parts))


def fingerprint(files):
  h = hashlib.sha1()
  for f in files:
    h.update(str(f).encode() + b"\0" + f.read_bytes() + b"\0")
  return h.hexdigest()


def run(cmd):
  return subprocess.run(cmd, cwd=PROJECT_DIR, capture_output=True, text=True)


def tail(text, lines=15):
  return "\n".join(text.strip().splitlines()[-lines:])


def violations(result):
  """One line per failed resource result: [FAIL|WARN] policy > rule: address: message."""
  lines = []
  for policy, rules in (result.get("policy_results") or {}).items():
    for rule in rules:
      for ev in (rule.get("evaluations") or {}).get("fails", []):
        for r in ev.get("result", []):
          if r.get("passed") is False:
            address = (r.get("meta") or {}).get("address", "-")
            lines.append(
              f"  - [{rule.get('onFail')}] {policy} > {rule.get('rule_name')}: {address}: "
              f"{ev.get('description') or ev.get('id')}: {r.get('message')}"
            )
  return lines


def check(tmp):
  """Returns the hook output dict."""
  if not (PROJECT_DIR / ".terraform").is_dir():
    init = run(["tofu", "init", "-input=false", "-no-color"])
    if init.returncode:
      return {"systemMessage": f"Tirith platform: tofu init failed, check skipped\n{tail(init.stderr)}"}

  plan_file = Path(tmp) / "tfplan"
  plan = run(["tofu", "plan", "-input=false", "-no-color", f"-out={plan_file}"])
  if plan.returncode:
    return {
      "decision": "block",
      "reason": (
        "`tofu plan` failed, so the Tirith platform check could not run. Fix it if the code is at "
        "fault; if it's credentials or missing terraform.tfvars, tell the user instead:\n"
        + tail(plan.stderr or plan.stdout)
      ),
    }

  result_file = Path(tmp) / "result.json"
  sha = run(["git", "rev-parse", "HEAD"]).stdout.strip()
  cmd = [
    str(TIRITH), "platform", "check",
    "--org", SG_ORG,
    "--workflow-group", WF_GROUP,
    "--workflow-id", WF_ID,
    "--plan-file", str(plan_file),
    "--terraform-bin", "tofu",
    "--source-dir", ".",
    "--timeout", "780",
    "--output-json", str(result_file),
  ]
  if sha:
    # The working tree usually differs from HEAD, so namespace the archive by input fingerprint
    cmd += ["--sha", sha, "--artifact-tag", STATE_FILE.read_text()[:12]]
  check_run = run(cmd)
  if not result_file.exists():
    return {"systemMessage": f"Tirith platform: no verdict\n{tail(check_run.stderr or check_run.stdout)}"}

  result = json.loads(result_file.read_text())
  headline = result.get("headline") or f"Tirith platform: {result.get('verdict')}"
  url = result.get("wfrun_url", "")
  counts = result.get("counts") or {}
  if not (counts.get("failed") or counts.get("warned") or counts.get("approval_required")):
    return {"systemMessage": f"{headline} ({url})"}

  return {
    "systemMessage": f"{headline} ({url})",
    "decision": "block",
    "reason": (
      f"StackGuardian Tirith platform check on {WF_GROUP}/{WF_ID}: {headline}.\n"
      + "\n".join(violations(result))
      + f"\nRun: {url}\n"
      "Fix FAIL results in the *.tf files. Fix WARN results if it fits the current task, "
      "otherwise mention them to the user. Don't weaken the policies."
    ),
  }


def main():
  force = "--force" in sys.argv
  event = {} if force else json.load(sys.stdin)
  files = inputs()
  if not files or event.get("hook_event_name", "Stop") != "Stop":
    return 0

  # One platform run per change of the inputs; also stops Stop -> block -> Stop loops
  current = fingerprint(files)
  try:
    previous = STATE_FILE.read_text()
  except OSError:
    previous = ""
  if previous == current and not force:
    return 0
  if not os.environ.get("SG_API_TOKEN"):
    print(json.dumps({"systemMessage": "Tirith platform: SG_API_TOKEN not set, check skipped"}))
    return 0
  STATE_FILE.write_text(current)

  with tempfile.TemporaryDirectory() as tmp:
    out = check(tmp)
  if force:
    print(out.get("reason") or out.get("systemMessage"))
    return 3 if out.get("decision") == "block" else 0
  print(json.dumps(out))
  return 0


if __name__ == "__main__":
  sys.exit(main())
