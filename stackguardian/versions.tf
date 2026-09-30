terraform {
  required_version = ">= 1.8.0"

  required_providers {
    stackguardian = {
      # Not published on registry.opentofu.org, so the full host is needed
      source  = "registry.terraform.io/StackGuardian/stackguardian"
      version = ">= 1.12.0, < 2.0.0"
    }
  }
}

# Credentials from STACKGUARDIAN_API_KEY, STACKGUARDIAN_ORG_NAME and STACKGUARDIAN_API_URI
provider "stackguardian" {
  api_uri  = "https://api.app.stackguardian.io"
  org_name = "wicked-hop"
}
