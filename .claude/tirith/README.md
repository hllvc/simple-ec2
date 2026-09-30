# Tirith platform check for Claude Code

`.claude/settings.json` registers a `Stop` hook (`.claude/hooks/tirith-platform-check.py`). When
Claude finishes a turn in which `*.tf`, `*.tfvars` or `*.tftpl` files changed, it runs
`tofu plan` and sends the plan to StackGuardian with `tirith platform check`. FAIL and WARN
results block the stop, so Claude gets them and fixes the code.

The policies are not in this repo. They are enforced by the org on the workflow and managed as
code on the `tirith` branch (`stackguardian/`).

| Setting | Default | Override |
| --- | --- | --- |
| Org | `wicked-hop` | `TIRITH_SG_ORG` or `SG_ORG` |
| Workflow group | `adis` | `TIRITH_WF_GROUP` |
| Workflow | `simple-ec2-tirith` | `TIRITH_WF_ID` |

Requirements:
- `SG_API_TOKEN` exported before starting Claude Code (without it the check is skipped)
- AWS credentials for `tofu plan`
- a local `terraform.tfvars` (gitignored) with `vpc_id` and `public_subnet_id`
- `uv`

Each change to the inputs triggers one platform run; the last fingerprint is kept in
`.claude/tirith-platform.state`. Run it by hand with `.claude/hooks/tirith-platform-check.py --force`
(exit 3 when a policy fails or warns).
