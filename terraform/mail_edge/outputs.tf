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

output "ses_configuration_set_name" {
  description = "SES configuration set to select from Mailu SMTP submissions for fine-grained event publishing."
  value       = var.enable_ses && var.enable_ses_monitoring ? aws_ses_configuration_set.mailu[0].name : null
}

output "ses_configuration_set_header" {
  description = "Optional SMTP header that explicitly selects the default Mailu SES configuration set."
  value       = var.enable_ses && var.enable_ses_monitoring ? "X-SES-CONFIGURATION-SET: ${aws_ses_configuration_set.mailu[0].name}" : null
}

output "ses_event_topic_arn" {
  description = "SNS topic receiving SES bounce, complaint, reject, and rendering-failure events."
  value       = var.enable_ses && var.enable_ses_monitoring ? aws_sns_topic.ses_events[0].arn : null
}

output "ses_event_queue_url" {
  description = "Encrypted SQS queue retaining SES failure events for 14 days."
  value       = var.enable_ses && var.enable_ses_monitoring ? aws_sqs_queue.ses_events[0].url : null
}

output "ses_alert_topic_arn" {
  description = "SNS topic receiving SES CloudWatch volume and reputation alarm notifications."
  value       = var.enable_ses && var.enable_ses_monitoring ? aws_sns_topic.ses_alerts[0].arn : null
}

output "ses_alarm_names" {
  description = "CloudWatch alarm names for SES outbound volume and account reputation."
  value = var.enable_ses && var.enable_ses_monitoring ? [
    aws_cloudwatch_metric_alarm.ses_send_volume[0].alarm_name,
    aws_cloudwatch_metric_alarm.ses_bounce_reputation[0].alarm_name,
    aws_cloudwatch_metric_alarm.ses_complaint_reputation[0].alarm_name,
  ] : []
}

output "ses_dns_records_to_create" {
  description = "SES DNS records to create manually when Route53 automation is not enabled."
  value       = local.manage_ses_dns_records ? [] : local.ses_dns_records
}

output "mail_dns_records_to_create" {
  description = "Public mail DNS records to create manually when Route53 automation is not enabled."
  value       = local.manage_public_mail_dns_records ? [] : local.mail_dns_records
}

output "recommended_public_mail_security_dns_records" {
  description = "Public DNS security records whose values are unambiguous from this module's SES-only outbound design. Review and publish manually."
  value       = local.recommended_public_mail_security_dns_records
}

output "reverse_dns_name" {
  description = "Hostname intended for Elastic IP reverse DNS."
  value       = local.effective_mail_hostname
}

output "reverse_dns_ptr_record" {
  description = "PTR record reported by AWS when reverse DNS is managed here."
  value       = try(aws_eip_domain_name.mail_edge[0].ptr_record, null)
}

output "email_canary_function_name" {
  description = "Lambda function name for the email canary."
  value       = var.enable_email_canary ? aws_lambda_function.email_canary[0].function_name : null
}

output "email_canary_alert_topic_arn" {
  description = "SNS topic ARN used by the email canary for alerts."
  value       = var.enable_email_canary ? aws_sns_topic.email_canary_alerts[0].arn : null
}

output "email_canary_schedule_expression" {
  description = "EventBridge schedule expression for the email canary."
  value       = var.enable_email_canary ? aws_cloudwatch_event_rule.email_canary[0].schedule_expression : null
}

output "email_canary_probe_names" {
  description = "Names of the email canary probes configured for the Lambda."
  value       = [for probe in local.email_canary_probes : probe.name]
}

output "open_relay_canary_alarm_names" {
  description = "CloudWatch alarms for critical, indeterminate, and missing-heartbeat relay canary results."
  value = var.enable_cloudwatch_observability && var.enable_open_relay_canary ? [
    aws_cloudwatch_metric_alarm.relay_canary_critical[0].alarm_name,
    aws_cloudwatch_metric_alarm.relay_canary_indeterminate[0].alarm_name,
    aws_cloudwatch_metric_alarm.relay_canary_heartbeat_missing[0].alarm_name,
  ] : []
}

output "open_relay_canary_target" {
  description = "WireGuard-side Mailu SMTP endpoint exercised by the edge-host relay canary."
  value       = var.enable_open_relay_canary ? "${local.effective_home_mailu_tunnel_ip}:25" : null
}

output "haproxy_log_group_name" {
  description = "CloudWatch Logs group containing structured HAProxy edge connection records."
  value       = var.enable_cloudwatch_observability ? aws_cloudwatch_log_group.mail_edge_haproxy[0].name : null
}

output "mail_edge_alert_topic_arn" {
  description = "SNS topic used by Mailu edge availability and abuse-volume alarms."
  value       = var.enable_cloudwatch_observability ? aws_sns_topic.mail_edge_alerts[0].arn : null
}
