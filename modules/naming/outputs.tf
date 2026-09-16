output "suffix" {
  description = "Random suffix used to keep resource names unique"
  value       = random_string.this.result
}

output "name" {
  description = "Prefixed name with the random suffix appended"
  value       = "${var.prefix}-${random_string.this.result}"
}
