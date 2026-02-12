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
  key_name   = "ec2-key-${random_string.this.result}"
  public_key = tls_private_key.this.public_key_openssh
}

# Security group for EC2 instance
resource "aws_security_group" "this" {
  name        = "ec2-sg-${random_string.this.result}"
  description = "Security group for EC2 instance - SSH access"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }
}

# EC2 instance
resource "aws_instance" "this" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  key_name                    = aws_key_pair.this.key_name
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "stop"
      spot_instance_type             = "persistent"
    }
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  user_data = var.auto_shutdown_idle_minutes > 0 ? <<-EOF
    #!/bin/bash

    cat > /usr/local/bin/auto-shutdown.sh << 'SCRIPT'
    #!/bin/bash
    IDLE_FILE="/tmp/idle-minutes"
    THRESHOLD_MINUTES=$${IDLE_THRESHOLD:-240}
    CPU_THRESHOLD=$${CPU_THRESHOLD:-5}

    [ ! -f "$IDLE_FILE" ] && echo 0 > "$IDLE_FILE"

    SSH_USERS=$(who | wc -l)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)

    if [ "$SSH_USERS" -eq 0 ] && [ "$CPU_USAGE" -lt "$CPU_THRESHOLD" ]; then
      CURRENT=$(cat "$IDLE_FILE")
      CURRENT=$((CURRENT + 1))
      echo "$CURRENT" > "$IDLE_FILE"
      if [ "$CURRENT" -ge "$THRESHOLD_MINUTES" ]; then
        shutdown -h now
      fi
    else
      echo 0 > "$IDLE_FILE"
    fi
    SCRIPT

    chmod +x /usr/local/bin/auto-shutdown.sh

    echo "* * * * * root IDLE_THRESHOLD=${var.auto_shutdown_idle_minutes} CPU_THRESHOLD=${var.auto_shutdown_cpu_threshold} /usr/local/bin/auto-shutdown.sh" > /etc/cron.d/auto-shutdown
    chmod 644 /etc/cron.d/auto-shutdown
  EOF
  : null
}
