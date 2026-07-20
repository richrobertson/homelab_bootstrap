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

variable "enable_cloudwatch_observability" {
  description = "Whether to centralize HAProxy edge logs in CloudWatch and create abuse/availability alarms. Requires Session Manager so State Manager can configure existing instances."
  type        = bool
  default     = true

  validation {
    condition     = !var.enable_cloudwatch_observability || var.enable_ssm_session_manager
    error_message = "enable_ssm_session_manager must be true when enable_cloudwatch_observability is enabled."
  }
}

variable "mail_edge_log_retention_days" {
  description = "CloudWatch Logs retention for structured HAProxy connection logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.mail_edge_log_retention_days)
    error_message = "mail_edge_log_retention_days must be a retention period supported by CloudWatch Logs."
  }
}

variable "mail_edge_local_log_max_bytes" {
  description = "Maximum persistent journald disk usage on the edge before old entries are vacuumed."
  type        = string
  default     = "512M"

  validation {
    condition     = can(regex("^[1-9][0-9]*[KMG]$", var.mail_edge_local_log_max_bytes))
    error_message = "mail_edge_local_log_max_bytes must be a systemd size such as 512M or 1G."
  }
}

variable "mail_edge_smtp_connection_alarm_threshold" {
  description = "Five-minute public SMTP connection count that triggers the edge abuse-volume alarm."
  type        = number
  default     = 25

  validation {
    condition     = var.mail_edge_smtp_connection_alarm_threshold > 0
    error_message = "mail_edge_smtp_connection_alarm_threshold must be greater than zero."
  }
}

variable "mail_edge_alert_phone_number" {
  description = "Optional E.164 phone number subscribed to Mailu edge CloudWatch alarm notifications."
  type        = string
  default     = null
  sensitive   = true
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

variable "enable_email_canary" {
  description = "Whether to create the Lambda email canary that sends a SES test message and verifies mailbox delivery."
  type        = bool
  default     = false
}

variable "email_canary_from_address" {
  description = "Verified SES sender address used by the email canary."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_email_canary || (var.email_canary_from_address != null && length(trimspace(var.email_canary_from_address)) > 0)
    error_message = "email_canary_from_address must be set when enable_email_canary is true."
  }
}

variable "email_canary_to_address" {
  description = "Recipient mailbox that the email canary checks through IMAP."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_email_canary || (var.email_canary_to_address != null && length(trimspace(var.email_canary_to_address)) > 0)
    error_message = "email_canary_to_address must be set when enable_email_canary is true."
  }
}

variable "email_canary_imap_secret_arn" {
  description = "Secrets Manager secret ARN containing IMAP settings as JSON: host, username, password, and optional port, folder, use_ssl."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = !var.enable_email_canary || (var.email_canary_imap_secret_arn != null && length(trimspace(var.email_canary_imap_secret_arn)) > 0)
    error_message = "email_canary_imap_secret_arn must be set when enable_email_canary is true."
  }
}

variable "email_canary_alert_phone_number" {
  description = "Optional E.164 cellphone number for SMS alerts, for example +15551234567. Leave null to publish only to the SNS topic."
  type        = string
  default     = null
  sensitive   = true
}

variable "email_canary_schedule_expression" {
  description = "EventBridge schedule expression for the canary."
  type        = string
  default     = "rate(5 minutes)"
}

variable "email_canary_delivery_timeout_seconds" {
  description = "Maximum end-to-end delivery time before the canary alerts."
  type        = number
  default     = 240
}

variable "email_canary_lambda_timeout_seconds" {
  description = "Lambda timeout. Keep this above email_canary_delivery_timeout_seconds plus a small buffer."
  type        = number
  default     = 300
}

variable "email_canary_log_retention_days" {
  description = "CloudWatch Logs retention for the email canary Lambda."
  type        = number
  default     = 14
}

variable "enable_open_relay_canary" {
  description = "Whether the scheduled email canary should perform an external RCPT-only open-relay check against the public MX path. Requires enable_email_canary."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_open_relay_canary || var.enable_email_canary
    error_message = "enable_open_relay_canary requires enable_email_canary so the scheduled Lambda and SNS alert path exist."
  }
}

variable "open_relay_canary_port" {
  description = "Public SMTP port for the RCPT-only open-relay check. Keep this at 25 to exercise the unauthenticated MX path."
  type        = number
  default     = 25

  validation {
    condition     = var.open_relay_canary_port >= 1 && var.open_relay_canary_port <= 65535
    error_message = "open_relay_canary_port must be a valid TCP port."
  }
}

variable "open_relay_canary_timeout_seconds" {
  description = "Socket timeout for each SMTP step in the RCPT-only open-relay check."
  type        = number
  default     = 10

  validation {
    condition     = var.open_relay_canary_timeout_seconds >= 1 && var.open_relay_canary_timeout_seconds <= 30
    error_message = "open_relay_canary_timeout_seconds must be between 1 and 30 seconds."
  }
}

variable "open_relay_canary_mail_from" {
  description = "Non-local RFC 2606 sender used by the RCPT-only open-relay check. No message body is transmitted."
  type        = string
  default     = "open-relay-canary@example.com"
}

variable "open_relay_canary_rcpt_to" {
  description = "Non-local RFC 2606 recipient used by the RCPT-only open-relay check. The transaction always stops before DATA."
  type        = string
  default     = "open-relay-canary@example.net"
}

variable "enable_mailu_dovecot_canary" {
  description = "Whether the email canary should also verify delivery into a Mailu-hosted mailbox through Dovecot IMAP."
  type        = bool
  default     = false
}

variable "mailu_dovecot_canary_from_address" {
  description = "Optional SES sender address for the Mailu Dovecot probe. Defaults to email_canary_from_address."
  type        = string
  default     = null
}

variable "mailu_dovecot_canary_to_address" {
  description = "Mailu-hosted recipient address that should receive the inbound probe."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_mailu_dovecot_canary || (var.mailu_dovecot_canary_to_address != null && length(trimspace(var.mailu_dovecot_canary_to_address)) > 0)
    error_message = "mailu_dovecot_canary_to_address must be set when enable_mailu_dovecot_canary is true."
  }
}

variable "mailu_dovecot_canary_imap_secret_arn" {
  description = "Secrets Manager secret ARN for the Mailu Dovecot IMAP credentials. Use host mail.myrobertson.net, port 993, use_ssl true to traverse the AWS edge into Kubernetes."
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = !var.enable_mailu_dovecot_canary || (var.mailu_dovecot_canary_imap_secret_arn != null && length(trimspace(var.mailu_dovecot_canary_imap_secret_arn)) > 0)
    error_message = "mailu_dovecot_canary_imap_secret_arn must be set when enable_mailu_dovecot_canary is true."
  }
}

variable "mailu_dovecot_canary_delivery_timeout_seconds" {
  description = "Maximum end-to-end delivery time for the Mailu Dovecot probe."
  type        = number
  default     = 240
}
