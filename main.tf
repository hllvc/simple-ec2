locals {
  name   = "${var.name_prefix}-${random_string.this.result}"
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
}

# Generate random string for unique resource naming
resource "random_string" "this" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# Generate SSH key pair
resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

# Create AWS key pair from generated public key
resource "aws_key_pair" "this" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.this.public_key_openssh
  tags       = var.tags
}

# Security group for EC2 instance
resource "aws_security_group" "this" {
  name        = "${local.name}-sg"
  description = "Security group for EC2 instance - SSH access"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_ingress_cidr_blocks
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Get latest Ubuntu 22.04 LTS AMI when no explicit AMI is provided
data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }
}

# EC2 instance
resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = var.associate_public_ip_address

  dynamic "instance_market_options" {
    for_each = var.use_spot_instance ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  user_data = var.auto_shutdown_idle_minutes > 0 ? templatefile(
    "${path.module}/templates/auto-shutdown.sh.tftpl",
    {
      idle_minutes  = var.auto_shutdown_idle_minutes
      cpu_threshold = var.auto_shutdown_cpu_threshold
    }
  ) : null

  tags = merge(var.tags, { Name = local.name })
}
