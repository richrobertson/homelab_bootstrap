output "talosconfig" {
  value     = length(module.kubernetes-cluster) == 0 ? "" : module.kubernetes-cluster[0].talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = length(module.kubernetes-cluster) == 0 ? "" : module.kubernetes-cluster[0].kubeconfig
  sensitive = true
}

output "mail_edge_instance_id" {
  description = "EC2 instance ID for the Mailu edge."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].instance_id)
}

output "mail_edge_elastic_ip" {
  description = "Elastic IP address for the Mailu edge."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].elastic_ip)
}

output "mail_edge_public_dns" {
  description = "AWS public DNS name for the Mailu edge instance."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].public_dns)
}

output "mail_edge_wireguard_endpoint" {
  description = "WireGuard endpoint hostname and port for the EC2 edge."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].wireguard_endpoint)
}

output "mail_edge_wireguard_server_public_key" {
  description = "WireGuard public key for the EC2 edge peer."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].wireguard_server_public_key)
}

output "mail_edge_wireguard_home_peer_config" {
  description = "Starter WireGuard peer configuration for the home side."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].wireguard_home_peer_config)
}

output "mail_edge_ses_smtp_endpoint" {
  description = "SES SMTP endpoint for the selected AWS region."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].ses_smtp_endpoint)
}

output "mail_edge_ses_smtp_username" {
  description = "SES SMTP username for Mailu/Postfix relay configuration."
  value       = length(module.mail_edge) == 0 ? null : module.mail_edge[0].ses_smtp_username
  sensitive   = true
}

output "mail_edge_ses_smtp_password" {
  description = "SES SMTP password for Mailu/Postfix relay configuration."
  value       = length(module.mail_edge) == 0 ? null : module.mail_edge[0].ses_smtp_password
  sensitive   = true
}

output "mail_edge_ses_dns_records_to_create" {
  description = "SES DNS records to create manually when Route53 automation is not enabled."
  value       = length(module.mail_edge) == 0 ? [] : nonsensitive(module.mail_edge[0].ses_dns_records_to_create)
  sensitive   = true
}

output "mail_edge_dns_records_to_create" {
  description = "Public mail A and MX records to create manually when Route53 automation is not enabled."
  value       = length(module.mail_edge) == 0 ? [] : nonsensitive(module.mail_edge[0].mail_dns_records_to_create)
}

output "mail_edge_authoritative_dns_records" {
  description = "Split-horizon/internal myrobertson.net DNS records managed directly through the AD-backed DNS provider for inbound mail, SES, and delegated ACME when enabled."
  value = !local.manage_authoritative_mail_dns ? [] : nonsensitive(compact(concat(
    [
      "A ${local.authoritative_mail_hostname} -> ${nonsensitive(module.mail_edge[0].elastic_ip)}",
      "MX ${var.mail_domain} -> 10 ${local.authoritative_mail_hostname}.",
    ],
    local.ses_verification_record == null ? [] : [
      "TXT _amazonses.${var.mail_domain}",
    ],
    [
      for record_name, _record in local.ses_dkim_records : "CNAME ${record_name}.${var.mail_domain}"
    ],
    local.ses_mail_from_mx_record == null ? [] : [
      "MX ${local.authoritative_mail_from_hostname}",
    ],
    local.ses_mail_from_txt_record == null ? [] : [
      "TXT ${local.authoritative_mail_from_hostname}",
    ],
    local.manage_mail_dns01_cname ? [
      "CNAME ${local.mail_certificate_dns01_authoritative_name}.${var.mail_domain} -> ${local.mail_certificate_dns01_delegate_fqdn}",
    ] : [],
  )))
  sensitive = true
}

output "mail_edge_certificate_dns01_cname" {
  description = "Delegated DNS-01 CNAME value for the public mail certificate."
  value = !local.manage_mail_dns01_cname ? null : {
    source = "${local.mail_certificate_dns01_authoritative_name}.${var.mail_domain}."
    target = local.mail_certificate_dns01_delegate_fqdn
  }
}

output "mail_edge_reverse_dns_name" {
  description = "Hostname intended for Elastic IP reverse DNS."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].reverse_dns_name)
}

output "mail_edge_reverse_dns_ptr_record" {
  description = "PTR record reported by AWS when Terraform-managed reverse DNS is enabled."
  value       = length(module.mail_edge) == 0 ? null : nonsensitive(module.mail_edge[0].reverse_dns_ptr_record)
}

output "mailu_initial_admin_account" {
  description = "Initial Mailu administrator account email address."
  value       = local.manage_mailu_app_secret ? local.mailu_initial_admin_user : null
}

output "mailu_home_service_ip" {
  description = "Home-side Mailu Service IP that the AWS edge should target across WireGuard."
  value       = local.env.environment_name == "prod" ? local.mailu_home_service_ip : null
}

output "mailu_vault_secret_paths" {
  description = "Vault paths seeded for the Mailu Kubernetes deployment."
  value = local.env.environment_name == "prod" ? {
    app       = local.manage_mailu_app_secret ? "secret/mailu/${local.env.environment_name}/app" : null
    ses_relay = local.manage_mailu_edge_secrets ? "secret/mailu/${local.env.environment_name}/ses-relay" : null
    config    = local.manage_mailu_edge_secrets ? "secret/mailu/${local.env.environment_name}/config" : null
  } : {}
}
