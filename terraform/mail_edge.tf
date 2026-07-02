locals {
  is_prod_environment       = local.env.environment_name == "prod"
  aws_region                = var.aws_region != null ? var.aws_region : local.volsync_s3_region
  mail_edge_name_prefix     = coalesce(var.name_prefix, "${local.env.environment_short_name}-mailu-edge")
  mailu_wireguard_config    = local.is_prod_environment ? data.vault_generic_secret.mailu_wireguard[0].data : {}
  mailu_email_canary_config = local.is_prod_environment ? data.vault_generic_secret.email_canary_config[0].data : {}

  prod_mail_domain        = coalesce(try(nonsensitive(local.mailu_email_canary_config["mail_domain"]), null), "myrobertson.net")
  effective_mail_domain   = var.mail_domain != null ? var.mail_domain : (local.is_prod_environment ? local.prod_mail_domain : null)
  effective_mail_hostname = var.mail_hostname != null ? var.mail_hostname : (local.effective_mail_domain == null ? null : "mail.${local.effective_mail_domain}")

  effective_mail_edge_enabled = local.is_prod_environment ? true : var.mail_edge_enabled
  effective_enable_ses        = var.enable_ses
  effective_tags = merge(
    local.is_prod_environment ? {
      Environment = "prod"
      Service     = "mailu"
    } : {},
    var.tags,
  )

  effective_home_mailu_tunnel_ip           = var.home_mailu_tunnel_ip != null ? var.home_mailu_tunnel_ip : (local.is_prod_environment ? try(nonsensitive(local.mailu_wireguard_config["home-mailu-ip"]), null) : null)
  effective_home_wireguard_peer_public_key = var.home_wireguard_peer_public_key != null ? var.home_wireguard_peer_public_key : (local.is_prod_environment ? try(nonsensitive(local.mailu_wireguard_config["home-public-key"]), null) : null)
  effective_wireguard_ec2_private_key      = var.wireguard_ec2_private_key != null ? var.wireguard_ec2_private_key : (local.is_prod_environment ? try(local.mailu_wireguard_config["ec2-private-key"], null) : null)
  effective_wireguard_ec2_public_key       = var.wireguard_ec2_public_key != null ? var.wireguard_ec2_public_key : (local.is_prod_environment ? try(nonsensitive(local.mailu_wireguard_config["ec2-public-key"]), null) : null)
  effective_wireguard_tunnel_cidr          = local.is_prod_environment ? coalesce(try(nonsensitive(local.mailu_wireguard_config["tunnel-cidr"]), null), var.wireguard_tunnel_cidr) : var.wireguard_tunnel_cidr
  effective_wireguard_home_allowed_ips     = length(var.wireguard_home_allowed_ips) > 0 ? var.wireguard_home_allowed_ips : (local.effective_home_mailu_tunnel_ip == null ? [] : ["${local.effective_home_mailu_tunnel_ip}/32"])

  effective_enable_email_canary           = local.is_prod_environment ? true : var.enable_email_canary
  effective_email_canary_from_address     = var.email_canary_from_address != null ? var.email_canary_from_address : (local.is_prod_environment ? try(nonsensitive(local.mailu_email_canary_config["from_address"]), null) : null)
  effective_email_canary_to_address       = var.email_canary_to_address != null ? var.email_canary_to_address : (local.is_prod_environment ? try(nonsensitive(local.mailu_email_canary_config["to_address"]), null) : null)
  effective_email_canary_imap_secret_arn  = var.email_canary_imap_secret_arn != null ? var.email_canary_imap_secret_arn : (local.is_prod_environment ? try(local.mailu_email_canary_config["imap_secret_arn"], null) : null)
  effective_email_canary_delivery_timeout = local.is_prod_environment ? tonumber(try(nonsensitive(local.mailu_email_canary_config["delivery_timeout_seconds"]), var.email_canary_delivery_timeout_seconds)) : var.email_canary_delivery_timeout_seconds

  effective_enable_mailu_dovecot_canary           = local.is_prod_environment ? true : var.enable_mailu_dovecot_canary
  effective_mailu_dovecot_canary_from_address     = var.mailu_dovecot_canary_from_address != null ? var.mailu_dovecot_canary_from_address : (local.is_prod_environment ? try(nonsensitive(local.mailu_email_canary_config["mailu_dovecot_from_address"]), null) : null)
  effective_mailu_dovecot_canary_to_address       = var.mailu_dovecot_canary_to_address != null ? var.mailu_dovecot_canary_to_address : (local.is_prod_environment ? try(nonsensitive(local.mailu_email_canary_config["mailu_dovecot_to_address"]), null) : null)
  effective_mailu_dovecot_canary_imap_secret_arn  = var.mailu_dovecot_canary_imap_secret_arn != null ? var.mailu_dovecot_canary_imap_secret_arn : (local.is_prod_environment ? try(local.mailu_email_canary_config["mailu_dovecot_imap_secret_arn"], null) : null)
  effective_mailu_dovecot_canary_delivery_timeout = local.is_prod_environment ? tonumber(try(nonsensitive(local.mailu_email_canary_config["mailu_dovecot_delivery_timeout_seconds"]), var.mailu_dovecot_canary_delivery_timeout_seconds)) : var.mailu_dovecot_canary_delivery_timeout_seconds
}

module "mail_edge" {
  count  = local.effective_mail_edge_enabled ? 1 : 0
  source = "./mail_edge"

  aws_region                                    = local.aws_region
  name_prefix                                   = local.mail_edge_name_prefix
  tags                                          = local.effective_tags
  create_vpc                                    = var.create_vpc
  vpc_id                                        = var.vpc_id
  subnet_id                                     = var.subnet_id
  admin_cidr_blocks                             = var.admin_cidr_blocks
  instance_type                                 = var.instance_type
  key_name                                      = var.key_name
  enable_ssm_session_manager                    = var.enable_ssm_session_manager
  wireguard_listen_port                         = var.wireguard_listen_port
  home_mailu_tunnel_ip                          = local.effective_home_mailu_tunnel_ip
  home_wireguard_peer_public_key                = local.effective_home_wireguard_peer_public_key
  wireguard_ec2_private_key                     = local.effective_wireguard_ec2_private_key
  wireguard_ec2_public_key                      = local.effective_wireguard_ec2_public_key
  wireguard_home_allowed_ips                    = local.effective_wireguard_home_allowed_ips
  wireguard_tunnel_cidr                         = local.effective_wireguard_tunnel_cidr
  mail_domain                                   = local.effective_mail_domain
  mail_hostname                                 = local.effective_mail_hostname
  route53_zone_id                               = var.route53_zone_id
  enable_ses                                    = local.effective_enable_ses
  manage_ses_route53_records                    = var.manage_ses_route53_records
  manage_public_mail_dns_records                = var.manage_public_mail_dns_records
  wait_for_ses_domain_verification              = var.wait_for_ses_domain_verification
  ses_mail_from_subdomain                       = var.ses_mail_from_subdomain
  configure_eip_reverse_dns                     = var.configure_eip_reverse_dns
  enable_email_canary                           = local.effective_enable_email_canary
  email_canary_from_address                     = local.effective_email_canary_from_address
  email_canary_to_address                       = local.effective_email_canary_to_address
  email_canary_imap_secret_arn                  = local.effective_email_canary_imap_secret_arn
  email_canary_alert_phone_number               = coalesce(var.email_canary_alert_phone_number, try(data.vault_generic_secret.email_canary_alerts[0].data["phone_number"], null))
  email_canary_delivery_timeout_seconds         = local.effective_email_canary_delivery_timeout
  enable_mailu_dovecot_canary                   = local.effective_enable_mailu_dovecot_canary
  mailu_dovecot_canary_from_address             = local.effective_mailu_dovecot_canary_from_address
  mailu_dovecot_canary_to_address               = local.effective_mailu_dovecot_canary_to_address
  mailu_dovecot_canary_imap_secret_arn          = local.effective_mailu_dovecot_canary_imap_secret_arn
  mailu_dovecot_canary_delivery_timeout_seconds = local.effective_mailu_dovecot_canary_delivery_timeout
}
