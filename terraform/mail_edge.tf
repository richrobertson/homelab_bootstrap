locals {
  aws_region            = var.aws_region != null ? var.aws_region : local.volsync_s3_region
  mail_edge_name_prefix = coalesce(var.name_prefix, "${local.env.environment_short_name}-mailu-edge")
}

module "mail_edge" {
  count  = var.mail_edge_enabled ? 1 : 0
  source = "./mail_edge"

  aws_region                       = local.aws_region
  name_prefix                      = local.mail_edge_name_prefix
  tags                             = var.tags
  create_vpc                       = var.create_vpc
  vpc_id                           = var.vpc_id
  subnet_id                        = var.subnet_id
  admin_cidr_blocks                = var.admin_cidr_blocks
  instance_type                    = var.instance_type
  key_name                         = var.key_name
  enable_ssm_session_manager       = var.enable_ssm_session_manager
  wireguard_listen_port            = var.wireguard_listen_port
  home_mailu_tunnel_ip             = var.home_mailu_tunnel_ip
  home_wireguard_peer_public_key   = var.home_wireguard_peer_public_key
  wireguard_ec2_private_key        = var.wireguard_ec2_private_key
  wireguard_ec2_public_key         = var.wireguard_ec2_public_key
  wireguard_home_allowed_ips       = var.wireguard_home_allowed_ips
  wireguard_tunnel_cidr            = var.wireguard_tunnel_cidr
  mail_domain                      = var.mail_domain
  mail_hostname                    = var.mail_hostname
  route53_zone_id                  = var.route53_zone_id
  enable_ses                       = var.enable_ses
  manage_ses_route53_records       = var.manage_ses_route53_records
  manage_public_mail_dns_records   = var.manage_public_mail_dns_records
  wait_for_ses_domain_verification = var.wait_for_ses_domain_verification
  ses_mail_from_subdomain          = var.ses_mail_from_subdomain
  configure_eip_reverse_dns        = var.configure_eip_reverse_dns
}
