# ========================================
# Instance Information
# ========================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.this.private_ip
}

# ========================================
# SSH Connection Details
# ========================================

output "ssh_host" {
  description = "SSH host address (public IP)"
  value       = aws_instance.this.public_ip
}

output "ssh_user" {
  description = "SSH username for the instance"
  value       = "ubuntu"
}

output "ssh_private_key" {
  description = "Private SSH key in PEM format (sensitive)"
  value       = tls_private_key.this.private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "Public SSH key"
  value       = tls_private_key.this.public_key_openssh
}

output "ssh_connection_string" {
  description = "SSH connection command"
  value       = "ssh -i <private_key_file> ubuntu@${aws_instance.this.public_ip}"
}

# ========================================
# Resource Identifiers
# ========================================

output "key_pair_name" {
  description = "Name of the AWS key pair"
  value       = aws_key_pair.this.key_name
}

output "security_group_id" {
  description = "ID of the security group attached to the instance"
  value       = aws_security_group.this.id
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = aws_instance.this.ami
}
