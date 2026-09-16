# Generate random string for unique resource naming
resource "random_string" "this" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}
