# Example variable definitions for the simple-ec2 module.
# Copy this file to terraform.tfvars and fill in the required values:
#
#   cp terraform.tfvars.example terraform.tfvars
#
# terraform.tfvars is git-ignored, so your real values stay out of version control.

# --- Required ---------------------------------------------------------------

# ID of an existing VPC to deploy the EC2 instance into.
vpc_id = "vpc-xxxxxxxx"

# ID of a public subnet within the VPC above.
public_subnet_id = "subnet-xxxxxxxx"

# --- Optional ---------------------------------------------------------------

# AWS region to deploy resources.
aws_region = "eu-central-1"

# EC2 instance type.
instance_type = "t3.micro"

# Minutes of inactivity before auto-shutdown (set to 0 to disable).
auto_shutdown_idle_minutes = 240

# CPU usage percentage below which the instance is considered idle.
auto_shutdown_cpu_threshold = 5
