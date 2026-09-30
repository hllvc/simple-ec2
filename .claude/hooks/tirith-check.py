#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "py-tirith @ git+https://github.com/StackGuardian/tirith.git@1.2.1",
#   "python-hcl2==8.1.4",
# ]
# ///
"""Claude Code PostToolUse hook: evaluate Tirith policies against the repo's *.tf files.

The HCL is parsed statically (no provider credentials, no `tofu plan`) and turned into a
minimal `terraform show -json`-shaped document, so the policies are plain
`stackguardian/terraform_plan` rules that also work on real plans and on StackGuardian.

  .claude/tirith/policies/fail/*.json  -> violations block: Claude is told to fix them
  .claude/tirith/policies/warn/*.json  -> violations are passed to Claude as context

Run by hand: .claude/hooks/tirith-check.py --all
"""

import hashlib
import json
import logging
import os
import sys
import tempfile
from pathlib import Path

import hcl2
from tirith.core.core import start_policy_evaluation_from_dict

# Tirith logs every evaluation step at INFO; keep hook output clean
logging.disable(logging.CRITICAL)

PROJECT_DIR = Path(os.environ.get("CLAUDE_PROJECT_DIR", Path(__file__).resolve().parents[2]))
POLICY_DIR = PROJECT_DIR / ".claude" / "tirith" / "policies"
SKIP_DIRS = {".terraform", ".claude", ".git"}
# Fingerprint of the last evaluated *.tf + policies, so Bash calls only re-check after a change
STATE_FILE = Path(tempfile.gettempdir()) / f"tirith-hook-{hashlib.sha1(str(PROJECT_DIR).encode()).hexdigest()[:12]}"


def fingerprint(files):
  h = hashlib.sha1()
  for f in files:
    h.update(str(f).encode() + b"\0" + f.read_bytes() + b"\0")
  return h.hexdigest()


def should_run(event, current):
  """Edits to *.tf always run; Bash runs only if it changed *.tf or policy files (sed, git checkout, ...)."""
  tool = event.get("tool_name", "")
  if tool in ("Edit", "Write", "MultiEdit"):
    return event.get("tool_input", {}).get("file_path", "").endswith(".tf")
  if tool == "Bash":
    try:
      return STATE_FILE.read_text() != current
    except OSError:
      return True
  return False


def unquote(value):
  """python-hcl2 keeps literal quotes ("\"t3.micro\""); strip them. Interpolations are None (unknown)."""
  if isinstance(value, str):
    if len(value) >= 2 and value[0] == value[-1] == '"':
      value = value[1:-1]
    return None if "${" in value else value
  if isinstance(value, list):
    return [v for v in (unquote(v) for v in value) if v is not None]
  if isinstance(value, dict):
    return {
      unquote(k): v
      for k, v in ((k, unquote(v)) for k, v in value.items() if not k.startswith("__"))
      if v is not None and k != "dynamic"
    }
  return value


def build_plan(tf_files):
  """Map resource/data blocks to resource_changes; unknown values are left out like `after_unknown`."""
  changes, errors = [], []
  for path in tf_files:
    try:
      with open(path) as f:
        doc = hcl2.load(f)
    except Exception as e:  # noqa: BLE001 - any parse failure is reported, not raised
      errors.append(f"{path.relative_to(PROJECT_DIR)}: HCL parse error: {str(e).splitlines()[0]}")
      continue
    for block, mode, actions in (("resource", "managed", ["create"]), ("data", "data", ["read"])):
      for entry in doc.get(block, []):
        entry: dict = unquote(entry)
        for rtype, named in entry.items():
          for name, body in named.items():
            prefix = "data." if mode == "data" else ""
            changes.append({
              "address": f"{prefix}{rtype}.{name}",
              "mode": mode,
              "type": rtype,
              "name": name,
              "change": {"actions": actions, "after": body or {"__file__": str(path.name)}},
            })
  plan = {"format_version": "1.2", "terraform_version": "static-hcl", "resource_changes": changes}
  return plan, errors


def failures(result):
  """Human-readable lines for every evaluator result that failed (skips are passed: null)."""
  lines = []
  for ev in result.get("evaluators", []):
    if ev.get("passed") is False:
      for r in ev.get("result", []):
        if r.get("passed") is False:
          lines.append(f"  - {ev.get('description') or ev['id']}: {r.get('message')}")
  lines += [f"  - error: {e}" for e in result.get("errors", [])]
  return lines


def evaluate(plan):
  report = {"fail": [], "warn": []}
  for level in report:
    for policy_file in sorted((POLICY_DIR / level).glob("*.json")):
      policy = json.loads(policy_file.read_text())
      result = start_policy_evaluation_from_dict(policy, plan)
      # final_result None means every check was skipped (nothing relevant), treat as pass
      if result.get("final_result") is False:
        name = policy.get("meta", {}).get("name", policy_file.stem)
        report[level].append(f"[{level.upper()}] {name} ({policy_file.relative_to(PROJECT_DIR)})")
        report[level] += failures(result)
  return report


def main():
  manual = "--all" in sys.argv
  event = {} if manual else json.load(sys.stdin)

  tf_files = sorted(p for p in PROJECT_DIR.rglob("*.tf") if not SKIP_DIRS & set(p.relative_to(PROJECT_DIR).parts))
  current = fingerprint(tf_files + sorted(POLICY_DIR.rglob("*.json")))
  if not manual and not should_run(event, current):
    return 0
  STATE_FILE.write_text(current)
  if not tf_files:
    return 0

  plan, parse_errors = build_plan(tf_files)
  report = evaluate(plan)
  fail, warn = report["fail"], report["warn"]

  if manual:
    print("\n".join(parse_errors + fail + warn) or "Tirith: all policies passed")
    return 3 if fail else 0

  if not (fail or warn or parse_errors):
    return 0

  body = "\n".join(parse_errors + fail + warn)
  n_fail = sum(line.startswith("[FAIL]") for line in fail)
  n_warn = sum(line.startswith("[WARN]") for line in warn)
  out: dict = {"systemMessage": f"Tirith: {n_fail} failing, {n_warn} warning policies"}
  if fail:
    out["decision"] = "block"
    out["reason"] = (
      "Tirith policy check FAILED on the Terraform/OpenTofu code. Fix these violations in the *.tf "
      "files (do not edit or weaken the policies unless the user asks):\n" + body
    )
  else:
    out["hookSpecificOutput"] = {
      "hookEventName": "PostToolUse",
      "additionalContext": (
        "Tirith policy check produced WARNINGS on the Terraform/OpenTofu code. Fix them if it fits "
        "the current task, otherwise mention them to the user:\n" + body
      ),
    }
  print(json.dumps(out))
  return 0


if __name__ == "__main__":
  sys.exit(main())
