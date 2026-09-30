# Tirith policies for Claude Code

`.claude/settings.json` registers a `PostToolUse` hook (`.claude/hooks/tirith-check.py`) that
evaluates these [Tirith](https://github.com/StackGuardian/tirith) policies against the repo's
`*.tf` files after Claude edits one (or after a Bash command changed one).

- `policies/fail/` — a violation blocks: Claude is told to fix the code.
- `policies/warn/` — a violation is passed to Claude as context.

Move a file between the two directories to change how strict it is.

The HCL is parsed statically and converted into a minimal `tofu show -json` shape, so no
credentials or `tofu plan` are needed. Values that come from variables or references count as
unknown and are skipped. The policies are plain `stackguardian/terraform_plan` rules, so they
also run against a real plan:

```bash
.claude/hooks/tirith-check.py --all        # check the repo by hand (exit 3 on FAIL)

tofu plan -out=tfplan && tofu show -json tfplan > plan.json
uvx --from "git+https://github.com/StackGuardian/tirith.git@1.2.1" tirith \
  -policy-path .claude/tirith/policies/fail/sg-no-public-ingress.json -input-path plan.json --fail-on-error
```

Requires `uv` (dependencies are declared inline in the hook script).
