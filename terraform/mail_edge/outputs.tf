output "instance_id" {
  description = "EC2 instance ID for the Mailu edge."
  value       = aws_instance.mail_edge.id
}

output "elastic_ip" {
  description = "Elastic IP address attached to the Mailu edge."
  value       = aws_eip.mail_edge.public_ip
}

output "public_dns" {
  description = "Public DNS name assigned by AWS to the EC2 instance."
  value       = aws_instance.mail_edge.public_dns
}

output "wireguard_endpoint" {
  description = "WireGuard public endpoint with port."
  value       = "${aws_eip.mail_edge.public_ip}:${var.wireguard_listen_port}"
}

output "wireguard_server_public_key" {
  description = "WireGuard public key for the EC2 edge."
  value       = var.wireguard_ec2_public_key
}

output "wireguard_home_peer_config" {
  description = "Starter WireGuard configuration for the home-side peer."
  value       = <<-EOT
    [Interface]
    Address = ${coalesce(var.home_mailu_tunnel_ip, cidrhost(var.wireguard_tunnel_cidr, 2))}/${split("/", var.wireguard_tunnel_cidr)[1]}
    PrivateKey = <set-your-home-private-key>

    [Peer]
    PublicKey = ${var.wireguard_ec2_public_key}
    Endpoint = ${aws_eip.mail_edge.public_ip}:${var.wireguard_listen_port}
    AllowedIPs = ${cidrhost(var.wireguard_tunnel_cidr, 1)}/32
    PersistentKeepalive = 25
  EOT
}

output "ses_smtp_endpoint" {
  description = "SES SMTP endpoint for the selected region."
  value       = var.enable_ses ? local.ses_smtp_endpoint : null
}

output "ses_smtp_username" {
  description = "SMTP username for Mailu/Postfix relay."
  value       = var.enable_ses ? aws_iam_access_key.ses_smtp[0].id : null
  sensitive   = true
}

output "ses_smtp_password" {
  description = "SMTP password for Mailu/Postfix relay."
  value       = var.enable_ses ? aws_iam_access_key.ses_smtp[0].ses_smtp_password_v4 : null
  sensitive   = true
}

output "ses_dns_records_to_create" {
  description = "SES DNS records to create manually when Route53 automation is not enabled."
  value       = local.manage_ses_dns_records ? [] : local.ses_dns_records
}

output "mail_dns_records_to_create" {
  description = "Public mail DNS records to create manually when Route53 automation is not enabled."
  value       = local.manage_public_mail_dns_records ? [] : local.mail_dns_records
}

output "reverse_dns_name" {
  description = "Hostname intended for Elastic IP reverse DNS."
  value       = local.effective_mail_hostname
}

output "reverse_dns_ptr_record" {
  description = "PTR record reported by AWS when reverse DNS is managed here."
  value       = try(aws_eip_domain_name.mail_edge[0].ptr_record, null)
}
