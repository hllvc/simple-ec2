variable "enforced_on" {
  description = "StackGuardian scopes the policy applies to"
  type        = list(string)
  default     = ["/wfgrps/adis/wfs/simple-ec2-tirith"]
}
