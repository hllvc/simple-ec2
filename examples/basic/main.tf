terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "vpc_id" {
  description = "ID of an existing VPC."
  type        = string
}

variable "subnet_id" {
  description = "ID of an existing public subnet within the VPC."
  type        = string
}

module "ec2" {
  source = "../../"

  name_prefix = "demo"
  vpc_id      = var.vpc_id
  subnet_id   = var.subnet_id

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "ssh_connection_string" {
  value = module.ec2.ssh_connection_string
}

output "ssh_private_key" {
  value     = module.ec2.ssh_private_key
  sensitive = true
}
