output "rules" {
  description = "Rule name to on_fail, as sent to StackGuardian"
  value       = { for name, rule in local.rules : name => rule.on_fail }
}
