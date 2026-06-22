# simple-ec2

A reusable Terraform/OpenTofu module that launches a single Ubuntu EC2 instance into an existing VPC/subnet. It generates a dedicated ED25519 SSH key pair, attaches a security group allowing SSH, and optionally runs as a persistent spot instance with idle-based auto-shutdown.

## Requirements

| Name      | Version   |
| --------- | --------- |
| terraform | >= 1.7.0  |
| aws       | >= 5.0    |
| random    | >= 3.0    |
| tls       | >= 4.0    |

The module declares provider requirements but does **not** configure providers. Configure the `aws` provider (region, credentials, etc.) in the root module that consumes it.

## Usage

```hcl
provider "aws" {
  region = "eu-central-1"
}

module "ec2" {
  source = "github.com/hllvc/simple-ec2//modular"

  name_prefix = "demo"
  vpc_id      = "vpc-0123456789abcdef0"
  subnet_id   = "subnet-0123456789abcdef0"

  tags = {
    Environment = "dev"
  }
}

output "ssh" {
  value = module.ec2.ssh_connection_string
}
```

A runnable example lives in [`examples/basic`](./examples/basic).

## Inputs

| Name                          | Description                                                                            | Type           | Default          | Required |
| ----------------------------- | -------------------------------------------------------------------------------------- | -------------- | ---------------- | :------: |
| `vpc_id`                      | ID of the VPC where the instance and security group are created.                       | `string`       | n/a              |   yes    |
| `subnet_id`                   | ID of the subnet to launch into. Use a public subnet for public IP access.             | `string`       | n/a              |   yes    |
| `name_prefix`                 | Prefix for created resource names; a random suffix is appended.                         | `string`       | `"ec2"`          |    no    |
| `instance_type`               | EC2 instance type.                                                                      | `string`       | `"t3.medium"`    |    no    |
| `ami_id`                      | AMI to use. When null, the latest Ubuntu 22.04 LTS (amd64) AMI is looked up.            | `string`       | `null`           |    no    |
| `associate_public_ip_address` | Whether to associate a public IP with the instance.                                    | `bool`         | `true`           |    no    |
| `ssh_ingress_cidr_blocks`     | CIDR blocks allowed to reach SSH (port 22).                                             | `list(string)` | `["0.0.0.0/0"]`  |    no    |
| `use_spot_instance`           | Request a persistent spot instance instead of on-demand.                               | `bool`         | `true`           |    no    |
| `root_volume_type`            | Root EBS volume type.                                                                   | `string`       | `"gp3"`          |    no    |
| `root_volume_size`            | Root EBS volume size in GiB.                                                            | `number`       | `20`             |    no    |
| `auto_shutdown_idle_minutes`  | Minutes of inactivity before auto-shutdown (0 to disable).                              | `number`       | `240`            |    no    |
| `auto_shutdown_cpu_threshold` | CPU usage percentage below which the instance is considered idle.                       | `number`       | `5`              |    no    |
| `tags`                        | Additional tags applied to all taggable resources.                                     | `map(string)`  | `{}`             |    no    |

## Outputs

| Name                    | Description                                  |
| ----------------------- | -------------------------------------------- |
| `instance_id`           | EC2 instance ID.                             |
| `public_ip`             | Public IP address of the instance.           |
| `private_ip`            | Private IP address of the instance.          |
| `ssh_host`              | SSH host address (public IP).                |
| `ssh_user`              | SSH username (`ubuntu`).                      |
| `ssh_private_key`       | Generated private SSH key (sensitive).       |
| `ssh_public_key`        | Generated public SSH key.                    |
| `ssh_connection_string` | Ready-to-use SSH command.                    |
| `key_pair_name`         | Name of the created AWS key pair.            |
| `security_group_id`     | ID of the attached security group.           |
| `ami_id`                | AMI ID used for the instance.                |
