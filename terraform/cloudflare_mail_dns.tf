locals {
  cloudflare_mail_zone_id = local.env.cloudflare_mail_zone_id
  manage_cloudflare_mail_dns = (
    local.env.environment_name == "prod" &&
    local.cloudflare_mail_zone_id != null &&
    var.mail_domain != null
  )

  cloudflare_mail_dns_records = {
    spf = {
      name    = var.mail_domain
      content = "v=spf1 include:amazonses.com -all"
      comment = "Mailu incident hardening: SES is the only outbound sender"
    }
    dmarc = {
      name    = "_dmarc.${var.mail_domain}"
      content = "v=DMARC1; p=quarantine; rua=mailto:reports@${var.mail_domain}; adkim=s; aspf=r; fo=1; pct=25"
      comment = "Mailu sender hardening: staged enforcement with aggregate reports sent to the monitored reports mailbox"
    }
    mta_sts = {
      name    = "_mta-sts.${var.mail_domain}"
      content = "v=STSv1; id=20260723T194500Z;"
      comment = null
    }
    tls_reporting = {
      name    = "_smtp._tls.${var.mail_domain}"
      content = "v=TLSRPTv1; rua=mailto:reports@${var.mail_domain}"
      comment = "SMTP TLS reporting to the monitored reports mailbox"
    }
  }

  cloudflare_mail_dns_record_ids = {
    dmarc         = "0708acc8b7cc365ecbf635f4d79a54e7"
    mta_sts       = "107abbc57c47d246be81fc449aeb1833"
    spf           = "8fb0e253f8198e1c7b2efbe24b5249b5"
    tls_reporting = "919367f906b1a7481b0b0fe8e99f8a6b"
  }
}

resource "cloudflare_dns_record" "mail" {
  for_each = local.manage_cloudflare_mail_dns ? local.cloudflare_mail_dns_records : {}

  zone_id = coalesce(local.cloudflare_mail_zone_id, "00000000000000000000000000000000")
  name    = each.value.name
  type    = "TXT"
  content = each.value.content
  comment = each.value.comment
  ttl     = 300
  proxied = false
}

import {
  for_each = local.manage_cloudflare_mail_dns ? local.cloudflare_mail_dns_record_ids : {}

  to = cloudflare_dns_record.mail[each.key]
  id = "${local.cloudflare_mail_zone_id}/${each.value}"
}

output "cloudflare_mail_dns_records" {
  description = "Production Cloudflare TXT records managed for mail authentication, MTA-STS, and TLS reporting."
  value       = { for key, record in cloudflare_dns_record.mail : key => record.name }
}
