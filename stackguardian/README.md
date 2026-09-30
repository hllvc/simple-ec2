# StackGuardian Tirith policies

OpenTofu root that manages the `simple-ec2-tirith` policy in the `wicked-hop` org, enforced on
`/wfgrps/adis/wfs/simple-ec2-tirith` (`variables.tf`).

Each file in `policies/` becomes one rule of the policy. The directory sets `on_fail`:

- `policies/fail/*.json` -> `FAIL` (rejects the run)
- `policies/warn/*.json` -> `WARN` (records a warning)

The rules are `stackguardian/terraform_plan` Tirith policies and are sent inline.

```bash
export STACKGUARDIAN_API_KEY=...          # e.g. "$SG_API_TOKEN"
export STACKGUARDIAN_ORG_NAME=wicked-hop
export STACKGUARDIAN_API_URI=https://api.app.stackguardian.io

tofu init
tofu plan -out=tfplan
tofu apply tfplan
```

Try a rule locally against a plan before changing it:

```bash
uvx --from "git+https://github.com/StackGuardian/tirith.git@1.2.1" tirith \
  -policy-path policies/fail/sg-no-public-ingress.json -input-path plan.json --fail-on-error
```

State is local (`terraform.tfstate`, gitignored).
