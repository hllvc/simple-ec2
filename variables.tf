variable "name_prefix" {
  description = "Prefix for naming created resources. A random suffix is appended for uniqueness."
  type        = string
  default     = "ec2"
}

variable "vpc_id" {
  description = "ID of the VPC where the EC2 instance and its security group will be created."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the EC2 instance will be launched. Use a public subnet if associate_public_ip_address is true."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID to use for the instance. When null, the latest Ubuntu 22.04 LTS (amd64) AMI from Canonical is used."
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the instance."
  type        = bool
  default     = true
}

variable "ssh_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the instance over SSH (port 22)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "use_spot_instance" {
  description = "Whether to request a persistent spot instance instead of on-demand."
  type        = bool
  default     = true
}

variable "root_volume_type" {
  description = "Type of the root EBS volume."
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB."
  type        = number
  default     = 20
}

variable "auto_shutdown_idle_minutes" {
  description = "Minutes of inactivity before the instance auto-shuts down (0 to disable)."
  type        = number
  default     = 240
}

variable "auto_shutdown_cpu_threshold" {
  description = "CPU usage percentage below which the instance is considered idle."
  type        = number
  default     = 5
}

variable "tags" {
  description = "Additional tags applied to all resources that support tagging."
  type        = map(string)
  default     = {}
}
