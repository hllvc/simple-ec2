output "name" {
  description = "Name produced by the module fetched over SSH"
  value       = module.naming.name
}

output "suffix" {
  description = "Random suffix produced by the module fetched over SSH"
  value       = module.naming.suffix
}
