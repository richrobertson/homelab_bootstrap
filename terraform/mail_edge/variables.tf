variable "aws_region" {
  description = "AWS region for SES and EC2 resources."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for mail edge resource names."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "create_vpc" {
  description = "Whether to create a dedicated VPC and public subnet."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Existing VPC ID to reuse when create_vpc is false."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Existing subnet ID to reuse when create_vpc is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_vpc || var.subnet_id != null
    error_message = "subnet_id must be set when create_vpc is false."
  }
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH when key_name is set."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type for the public mail edge."
  type        = string
  default     = "t4g.nano"
}

variable "ami_id" {
  description = "Optional AMI ID override for the mail edge instance. Set this when the caller cannot read the public SSM AMI parameter."
  type        = string
  default     = null
}

variable "subnet_availability_zone" {
  description = "Optional availability zone override for the dedicated public subnet. Leave unset to let AWS choose or to use the first discovered zone when permissions allow."
  type        = string
  default     = null
}

variable "key_name" {
  description = "Optional key pair name for SSH access."
  type        = string
  default     = null
}

variable "enable_ssm_session_manager" {
  description = "Whether to attach Session Manager IAM permissions to the instance."
  type        = bool
  default     = true
}

variable "wireguard_listen_port" {
  description = "UDP port used by the WireGuard listener."
  type        = number
  default     = 51820
}

variable "home_mailu_tunnel_ip" {
  description = "Home-side Mailu IP reachable through the WireGuard tunnel."
  type        = string
  default     = null
}

variable "home_wireguard_peer_public_key" {
  description = "Public key for the home WireGuard peer."
  type        = string

  validation {
    condition     = var.home_wireguard_peer_public_key != null && length(trimspace(var.home_wireguard_peer_public_key)) > 0
    error_message = "home_wireguard_peer_public_key must be provided."
  }
}

variable "wireguard_ec2_private_key" {
  description = "Private key for the EC2 WireGuard interface."
  type        = string
  sensitive   = true

  validation {
    condition     = var.wireguard_ec2_private_key != null && length(trimspace(var.wireguard_ec2_private_key)) > 0
    error_message = "wireguard_ec2_private_key must be provided."
  }
}

variable "wireguard_ec2_public_key" {
  description = "Public key that corresponds to wireguard_ec2_private_key."
  type        = string

  validation {
    condition     = var.wireguard_ec2_public_key != null && length(trimspace(var.wireguard_ec2_public_key)) > 0
    error_message = "wireguard_ec2_public_key must be provided."
  }
}

variable "wireguard_home_allowed_ips" {
  description = "CIDR routes that the EC2 peer should direct to the home WireGuard peer."
  type        = list(string)
  default     = []
}

variable "wireguard_tunnel_cidr" {
  description = "CIDR block for the WireGuard tunnel."
  type        = string
  default     = "10.77.0.0/30"

  validation {
    condition     = can(cidrhost(var.wireguard_tunnel_cidr, 2))
    error_message = "wireguard_tunnel_cidr must allow at least two usable host addresses."
  }
}

variable "mail_domain" {
  description = "Domain used for inbound MX and SES verification."
  type        = string

  validation {
    condition     = var.mail_domain != null && length(trimspace(var.mail_domain)) > 0
    error_message = "mail_domain must be provided."
  }
}

variable "mail_hostname" {
  description = "Public hostname for the inbound mail edge."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone ID."
  type        = string
  default     = null
}

variable "enable_ses" {
  description = "Whether to create SES identity and SMTP credentials."
  type        = bool
  default     = true
}

variable "manage_ses_route53_records" {
  description = "Whether to create SES Route53 records when route53_zone_id is provided."
  type        = bool
  default     = true
}

variable "manage_public_mail_dns_records" {
  description = "Whether to create public A and MX Route53 records when route53_zone_id is provided."
  type        = bool
  default     = false
}

variable "wait_for_ses_domain_verification" {
  description = "Whether Terraform should wait for SES domain verification when verification DNS is managed here."
  type        = bool
  default     = true
}

variable "ses_mail_from_subdomain" {
  description = "Subdomain used as the SES custom MAIL FROM domain."
  type        = string
  default     = "bounce"
}

variable "configure_eip_reverse_dns" {
  description = "Whether to manage Elastic IP reverse DNS in Terraform when the forward A record is also managed here."
  type        = bool
  default     = false
}
