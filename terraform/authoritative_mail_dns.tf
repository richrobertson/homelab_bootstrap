locals {
  manage_authoritative_mail_dns = local.env.environment_name == "prod" && length(module.mail_edge) > 0 && var.manage_authoritative_mail_dns_records && var.mail_domain != null
  manage_authoritative_ses_dns  = local.manage_authoritative_mail_dns && var.enable_ses && var.manage_authoritative_ses_dns_records
  manage_mail_dns01_cname       = local.manage_authoritative_mail_dns && var.manage_mail_certificate_dns01_cname && var.mail_certificate_dns01_delegate_zone != null

  authoritative_mail_zone             = var.mail_domain == null ? null : "${var.mail_domain}."
  authoritative_mail_hostname         = var.mail_domain == null ? null : coalesce(var.mail_hostname, "mail.${var.mail_domain}")
  authoritative_mail_record_name      = local.authoritative_mail_hostname == null || local.authoritative_mail_hostname == var.mail_domain ? null : trimsuffix(local.authoritative_mail_hostname, ".${var.mail_domain}")
  authoritative_mail_from_hostname    = var.mail_domain == null ? null : "${var.ses_mail_from_subdomain}.${var.mail_domain}"
  authoritative_mail_from_record_name = local.authoritative_mail_from_hostname == null || local.authoritative_mail_from_hostname == var.mail_domain ? null : trimsuffix(local.authoritative_mail_from_hostname, ".${var.mail_domain}")
  authoritative_mail_autoconfig_records = local.manage_authoritative_mail_dns ? {
    autoconfig   = local.authoritative_mail_hostname
    autodiscover = local.authoritative_mail_hostname
  } : {}

  authoritative_ses_records = length(module.mail_edge) == 0 ? [] : module.mail_edge[0].ses_dns_records_to_create
  ses_verification_record = local.manage_authoritative_ses_dns ? one([
    for record in local.authoritative_ses_records : record
    if record.type == "TXT" && record.name == "_amazonses.${var.mail_domain}"
  ]) : null
  ses_mail_from_mx_record = local.manage_authoritative_ses_dns ? one([
    for record in local.authoritative_ses_records : record
    if record.type == "MX" && record.name == local.authoritative_mail_from_hostname
  ]) : null
  ses_mail_from_txt_record = local.manage_authoritative_ses_dns ? one([
    for record in local.authoritative_ses_records : record
    if record.type == "TXT" && record.name == local.authoritative_mail_from_hostname
  ]) : null
  ses_mail_from_mx_preference = local.ses_mail_from_mx_record == null ? null : tonumber(split(" ", local.ses_mail_from_mx_record.records[0])[0])
  ses_mail_from_mx_exchange = local.ses_mail_from_mx_record == null ? null : (
    endswith(split(" ", local.ses_mail_from_mx_record.records[0])[1], ".") ?
    split(" ", local.ses_mail_from_mx_record.records[0])[1] :
    "${split(" ", local.ses_mail_from_mx_record.records[0])[1]}."
  )
  ses_dkim_records = local.manage_authoritative_ses_dns ? {
    for record in local.authoritative_ses_records : trimsuffix(record.name, ".${var.mail_domain}") => record
    if record.type == "CNAME"
  } : {}

  mail_certificate_dns01_delegate_zone = var.mail_certificate_dns01_delegate_zone == null ? null : trimsuffix(var.mail_certificate_dns01_delegate_zone, ".")
  mail_certificate_dns01_delegate_record_name = !local.manage_mail_dns01_cname ? null : coalesce(
    var.mail_certificate_dns01_delegate_record_name,
    "_acme-challenge.${replace(local.authoritative_mail_hostname, ".", "-")}",
  )
  mail_certificate_dns01_delegate_fqdn = !local.manage_mail_dns01_cname ? null : "${local.mail_certificate_dns01_delegate_record_name}.${local.mail_certificate_dns01_delegate_zone}."
  mail_certificate_dns01_authoritative_name = !local.manage_mail_dns01_cname ? null : (
    local.authoritative_mail_record_name == null ? "_acme-challenge" : "_acme-challenge.${local.authoritative_mail_record_name}"
  )
}

resource "dns_a_record_set" "mail_edge_public" {
  count = local.manage_authoritative_mail_dns ? 1 : 0

  zone      = local.authoritative_mail_zone
  name      = local.authoritative_mail_record_name
  addresses = [module.mail_edge[0].elastic_ip]
  ttl       = 300
}

resource "dns_mx_record_set" "mail_domain" {
  count = local.manage_authoritative_mail_dns ? 1 : 0

  zone = local.authoritative_mail_zone
  name = null
  ttl  = 300

  mx {
    preference = 10
    exchange   = "${local.authoritative_mail_hostname}."
  }
}

resource "dns_cname_record" "mail_autoconfig" {
  for_each = local.authoritative_mail_autoconfig_records

  zone  = local.authoritative_mail_zone
  name  = each.key
  ttl   = 300
  cname = "${each.value}."
}

resource "dns_txt_record_set" "ses_verification" {
  count = local.ses_verification_record == null ? 0 : 1

  zone = local.authoritative_mail_zone
  name = "_amazonses"
  ttl  = local.ses_verification_record.ttl
  txt = [
    for value in local.ses_verification_record.records : trimsuffix(trimprefix(value, "\""), "\"")
  ]
}

resource "dns_cname_record" "ses_dkim" {
  for_each = local.ses_dkim_records

  zone  = local.authoritative_mail_zone
  name  = each.key
  ttl   = each.value.ttl
  cname = endswith(each.value.records[0], ".") ? each.value.records[0] : "${each.value.records[0]}."
}

resource "dns_mx_record_set" "ses_mail_from" {
  count = local.ses_mail_from_mx_record == null ? 0 : 1

  zone = local.authoritative_mail_zone
  name = local.authoritative_mail_from_record_name
  ttl  = local.ses_mail_from_mx_record.ttl

  mx {
    preference = local.ses_mail_from_mx_preference
    exchange   = local.ses_mail_from_mx_exchange
  }
}

resource "dns_txt_record_set" "ses_mail_from" {
  count = local.ses_mail_from_txt_record == null ? 0 : 1

  zone = local.authoritative_mail_zone
  name = local.authoritative_mail_from_record_name
  ttl  = local.ses_mail_from_txt_record.ttl
  txt = [
    for value in local.ses_mail_from_txt_record.records : trimsuffix(trimprefix(value, "\""), "\"")
  ]
}

resource "dns_cname_record" "mail_certificate_dns01_delegate" {
  count = local.manage_mail_dns01_cname ? 1 : 0

  zone  = local.authoritative_mail_zone
  name  = local.mail_certificate_dns01_authoritative_name
  ttl   = 300
  cname = local.mail_certificate_dns01_delegate_fqdn
}
