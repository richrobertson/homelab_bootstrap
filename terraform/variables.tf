variable "enable_talos_cluster_health_check" {
  description = "Whether to run Talos cluster health checks during plan/apply."
  type        = bool
  default     = true
}

variable "volsync_s3_settings_vault_path" {
  description = "Vault path to a VolSync S3 secret containing AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and RESTIC_REPOSITORY."
  type        = string
  default     = "secret/volsync/prod/plex-config-ceph"
}

variable "volsync_s3_region_override" {
  description = "Optional override for the AWS region derived from VolSync RESTIC_REPOSITORY."
  type        = string
  default     = null
}

variable "talos_etcd_backup_s3" {
  description = "Optional Talos etcd backup configuration for S3. Set to null to disable managed etcd backups."
  type        = any
  default     = null
  sensitive   = true

  validation {
    condition = var.talos_etcd_backup_s3 == null || alltrue([
      can(var.talos_etcd_backup_s3.bucket),
      can(var.talos_etcd_backup_s3.region),
      can(var.talos_etcd_backup_s3.access_key_id),
      can(var.talos_etcd_backup_s3.secret_access_key)
    ])
    error_message = "talos_etcd_backup_s3 must include bucket, region, access_key_id, and secret_access_key when set."
  }
}

variable "aws_region" {
  description = "AWS region for AWS-backed infrastructure. Defaults to the existing VolSync-derived region when unset."
  type        = string
  default     = null
}

variable "aws_access_key_id" {
  description = "Optional AWS access key ID override for environments that cannot read the Vault-backed AWS credentials."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "Optional AWS secret access key override for environments that cannot read the Vault-backed AWS credentials."
  type        = string
  default     = null
  sensitive   = true
}

variable "name_prefix" {
  description = "Prefix used for AWS mail edge resource names. Defaults to a workspace-derived prefix when unset."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional AWS tags to apply to mail edge resources."
  type        = map(string)
  default     = {}
}

variable "mail_edge_enabled" {
  description = "Whether to create the AWS Mailu edge and SES resources."
  type        = bool
  default     = false
}

variable "create_vpc" {
  description = "Whether to create a dedicated low-cost VPC and public subnet for the mail edge EC2 instance."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Existing VPC ID to reuse when create_vpc is false."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Existing public subnet ID to reuse when create_vpc is false."
  type        = string
  default     = null
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH when key_name is set. SSH is not opened to the world."
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type for the public mail edge."
  type        = string
  default     = "t4g.nano"
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access. SSH ingress is only created when this is set and admin_cidr_blocks is non-empty."
  type        = string
  default     = null
}

variable "enable_ssm_session_manager" {
  description = "Whether to attach the AmazonSSMManagedInstanceCore policy and instance profile for Session Manager access."
  type        = bool
  default     = true
}

variable "wireguard_listen_port" {
  description = "UDP port used by the WireGuard listener on the EC2 mail edge."
  type        = number
  default     = 51820
}

variable "home_mailu_tunnel_ip" {
  description = "Home-side Mailu front-end IP reachable across the WireGuard tunnel. Defaults to the second usable IP in wireguard_tunnel_cidr when unset."
  type        = string
  default     = null
}

variable "home_wireguard_peer_public_key" {
  description = "Public key for the home WireGuard peer that will receive forwarded Mailu traffic."
  type        = string
  default     = null
}

variable "wireguard_ec2_private_key" {
  description = "Private key for the EC2 WireGuard interface."
  type        = string
  default     = null
  sensitive   = true
}

variable "wireguard_ec2_public_key" {
  description = "Public key corresponding to wireguard_ec2_private_key. This is required because Terraform cannot safely derive WireGuard public keys natively."
  type        = string
  default     = null
}

variable "wireguard_home_allowed_ips" {
  description = "Routes advertised to the EC2 WireGuard peer for the home side. Defaults to the home_mailu_tunnel_ip /32 when unset."
  type        = list(string)
  default     = []
}

variable "wireguard_tunnel_cidr" {
  description = "CIDR used for the WireGuard tunnel between EC2 and the home Mailu peer."
  type        = string
  default     = "10.77.0.0/30"
}

variable "mail_domain" {
  description = "Primary mail domain used for SES and the inbound MX record."
  type        = string
  default     = null
}

variable "mail_hostname" {
  description = "Public hostname for the EC2 mail edge. Defaults to mail.<mail_domain> when unset."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone ID. When provided, SES DNS records can be created automatically and public mail A/MX records can optionally be managed."
  type        = string
  default     = null
}

variable "enable_ses" {
  description = "Whether to provision SES identity and SMTP credentials for outbound relay."
  type        = bool
  default     = true
}

variable "manage_ses_route53_records" {
  description = "Whether to create SES verification, DKIM, and MAIL FROM Route53 records when route53_zone_id is provided."
  type        = bool
  default     = true
}

variable "manage_public_mail_dns_records" {
  description = "Whether to create the public mail edge A and MX Route53 records when route53_zone_id is provided."
  type        = bool
  default     = false
}

variable "manage_authoritative_mail_dns_records" {
  description = "Whether to create split-horizon/internal myrobertson.net inbound A and MX records via the AD-backed RFC2136/GSS-TSIG DNS provider. This does not update the public Cloudflare zone."
  type        = bool
  default     = false
}

variable "manage_authoritative_ses_dns_records" {
  description = "Whether to create split-horizon/internal SES verification, DKIM, and MAIL FROM records in AD-backed myrobertson.net DNS. This does not update the public Cloudflare zone."
  type        = bool
  default     = false
}

variable "manage_mail_certificate_dns01_cname" {
  description = "Whether to create a split-horizon/internal _acme-challenge CNAME in AD-backed myrobertson.net DNS. Public Mailu ACME delegation for myrobertson.net lives in Cloudflare."
  type        = bool
  default     = false
}

variable "mail_certificate_dns01_delegate_zone" {
  description = "Zone that cert-manager is allowed to update for the delegated DNS-01 target. This repo uses myrobertson.com via the existing Cloudflare issuer."
  type        = string
  default     = "myrobertson.com"
}

variable "mail_certificate_dns01_delegate_record_name" {
  description = "Optional record name within mail_certificate_dns01_delegate_zone to use as the delegated DNS-01 target. Defaults to a hostname-derived _acme-challenge alias."
  type        = string
  default     = null
}

variable "wait_for_ses_domain_verification" {
  description = "Whether Terraform should wait for SES domain verification after creating Route53 verification records."
  type        = bool
  default     = true
}

variable "ses_mail_from_subdomain" {
  description = "Subdomain to use for SES custom MAIL FROM. Defaults to bounce to keep it separate from the inbound receive hostname."
  type        = string
  default     = "bounce"
}

variable "configure_eip_reverse_dns" {
  description = "Whether to attempt Terraform-managed reverse DNS on the Elastic IP when the forward A record is also managed in Route53."
  type        = bool
  default     = false
}
