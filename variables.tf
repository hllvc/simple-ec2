variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "network" {
  description = "Network placement for the EC2 instance"
  type = object({
    vpc_id    = string
    subnet_id = string
  })
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "auto_shutdown" {
  description = "Auto-shutdown on idle (set idle = 0 to disable)"
  type = object({
    idle      = number # minutes of inactivity before shutdown
    threshold = number # CPU % below which the instance is considered idle
  })
  default = {
    idle      = 240
    threshold = 5
  }
}
