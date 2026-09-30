# The directory (fail/ or warn/) sets on_fail
locals {
  policy_dir = "${path.module}/policies"

  rules = {
    for f in sort(fileset(local.policy_dir, "*/*.json")) :
    trimsuffix(basename(f), ".json") => {
      on_fail = upper(dirname(f))
      body    = jsondecode(file("${local.policy_dir}/${f}"))
    }
  }
}

resource "stackguardian_policy" "simple_ec2" {
  resource_name = "simple-ec2-tirith"
  description   = "EC2 guardrails shared with the Claude Code Tirith hook"
  policy_type   = "GENERAL"
  enforced_on   = var.enforced_on

  policies_config = [
    for name, rule in local.rules : {
      name    = name
      skip    = false
      on_fail = rule.on_fail
      on_pass = "PASS"
      policy_input_data = {
        schema_type = "TIRITH_JSON"
        data        = jsonencode(rule.body)
      }
      policy_vcs_config = {
        use_marketplace_template = false
        custom_source = {
          source_config_kind      = "SG_POLICY_FRAMEWORK"
          source_config_dest_kind = "INLINE"
        }
      }
    }
  ]
}
