variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_id" {
  description = "ID of the VPC where the EC2 instance will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet where the EC2 instance will be deployed"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "auto_shutdown_idle_minutes" {
  description = "Minutes of inactivity before auto-shutdown (0 to disable)"
  type        = number
  default     = 240
}

variable "auto_shutdown_cpu_threshold" {
  description = "CPU usage percentage below which the instance is considered idle"
  type        = number
  default     = 5
}

variable "environment" {
  description = "Environment name used in resource tags"
  type        = string
  default     = "recovery-test"
}

variable "data_volume_size" {
  description = "Size in GiB of an extra EBS data volume attached to the instance (0 to disable)"
  type        = number
  default     = 10
}
