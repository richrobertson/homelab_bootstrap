# Mail Edge Operations

Use this runbook after reviewing the [mail edge design](../design/mail-edge.md)
and [mail_edge component README](../../terraform/mail_edge/README.md).

## Required Inputs

At minimum, set:

- `mail_edge_enabled = true`
- `mail_domain`
- `home_wireguard_peer_public_key`
- `wireguard_ec2_private_key`
- `wireguard_ec2_public_key`

For continuous SES delivery checks, also set `enable_email_canary = true` plus
`email_canary_from_address`, `email_canary_to_address`,
`email_canary_imap_secret_arn`. SMS delivery uses the `phone_number` key from
`email_canary_alerts_vault_path`, which defaults to
`secret/mailu/prod/email-canary-alerts`.

To verify delivery into Kubernetes-hosted Mailu Dovecot folders, set
`enable_mailu_dovecot_canary = true` plus
`mailu_dovecot_canary_to_address` and
`mailu_dovecot_canary_imap_secret_arn`.

To detect a recurrence of unauthenticated SMTP relaying, set
`enable_open_relay_canary = true` after confirming the Lambda can reach the
public MX on port 25. The canary is deliberately RCPT-only and never sends a
message body.

Generate the EC2 WireGuard keypair before applying. Terraform expects both
halves explicitly so it can bootstrap the instance and render the home peer
config without depending on a local shell helper.

For the production Mailu overlay, use the expected home-side Mailu Service IP:

```hcl
home_mailu_tunnel_ip       = "10.31.0.73"
wireguard_home_allowed_ips = ["10.31.0.73/32"]
```

## Post-Apply Steps

1. Bring up the EC2 edge and confirm the WireGuard endpoint from
   `mail_edge_wireguard_endpoint`.
2. Build the home peer config from `mail_edge_wireguard_home_peer_config`, add
   the home private key, and start the home WireGuard peer.
3. Make sure the home peer can route traffic for `home_mailu_tunnel_ip` to the
   Mailu front end or ingress.
4. Confirm that Mailu is listening for the forwarded ports on the home-side
   target IP.
5. Point public DNS `A` and `MX` records if Route53 or authoritative DNS
   automation is not managing them.
6. Reconcile the Mailu Flux overlay after the Vault secrets appear so the
   cluster picks up the relay credentials.
7. Confirm the SES identity reports `mail_edge_ses_configuration_set_name` as
   its default configuration set.
8. Send a test message and confirm its `Send` and `Delivery` metrics appear in
   CloudWatch with the `ses:configuration-set` dimension.

## SES Events and Reputation Alarms

`enable_ses_monitoring` defaults to true with the mail edge. Terraform creates
separate SNS topics for raw SES failure events and actionable CloudWatch alarms:

- `mail_edge_ses_event_topic_arn` receives bounce, complaint, reject, and
  rendering-failure events. Terraform subscribes an encrypted SQS queue with
  14-day retention; use `mail_edge_ses_event_queue_url` for incident analysis.
  Raw failure events intentionally have no SMS subscription.
- `mail_edge_ses_alert_topic_arn` receives the send-surge, account bounce-rate,
  and account complaint-rate alarms. When the existing canary phone number is
  configured, it is also subscribed to this alert topic.

The send-volume alarm uses the account-level `AWS/SES` `Send` metric, so it
works as soon as the resources are applied. The bounce and complaint alarms use
the free account-level SES reputation metrics. Terraform sets the configuration
set as the identity default, so event metrics apply to Mailu SMTP traffic
automatically. They may incur standard CloudWatch custom-metric charges; paid
Virtual Deliverability Manager is not enabled.

Before production apply, review `ses_send_volume_threshold` against expected
recipient volume. The default is 100 recipients per five minutes. The default
bounce and complaint thresholds are intentionally below the AWS account-review
levels.

## Email Canary

The optional email canary runs from AWS Lambda every five minutes. It can run
both an external delivery/reputation probe and a Mailu Dovecot probe in the
same invocation. Each probe sends a unique message through SES, polls the
configured recipient mailbox over IMAP, and publishes an SNS alert, including
SMS when configured, if SES rejects the send or the message is not visible
before the timeout.

Create the IMAP settings as an AWS Secrets Manager secret before enabling the
canary:

```json
{
  "host": "imap.example.com",
  "username": "canary@example.com",
  "password": "example-password",
  "folder": "INBOX",
  "port": 993,
  "use_ssl": true
}
```

Store the SMS destination in Vault:

```sh
vault kv put secret/mailu/prod/email-canary-alerts phone_number="+15551234567"
```

Use a mailbox outside the SES/Mailu path when possible. That makes delayed
delivery, receiver-side reputation blocks, and filtering failures show up as a
missed canary instead of only proving local loopback.

For the Mailu Dovecot probe, create a separate secret for a Mailu-hosted
mailbox and point IMAP at the public edge hostname:

```json
{
  "host": "mail.myrobertson.net",
  "username": "canary@myrobertson.net",
  "password": "example-password",
  "folder": "INBOX",
  "port": 993,
  "use_ssl": true
}
```

That path verifies `SES -> public MX -> AWS edge -> WireGuard ->
mailu-front-ext on 10.31.0.73 -> Mailu/Dovecot -> IMAP folder`.

## HAProxy Source-IP Logs

With `enable_mail_edge_cloudwatch_observability = true`, use output
`mail_edge_haproxy_log_group_name` to open the edge log group. The default
CloudWatch retention is 30 days. The edge also keeps up to seven days of
bounded persistent journal and rotated export data for short CloudWatch
outages.

Use this Logs Insights query to identify public SMTP contributors:

```text
fields @timestamp, source_ip, source_port, duration_ms, bytes_read, termination_state
| filter event = "connection" and frontend = "fe_mail_25"
| stats count(*) as connections,
        sum(bytes_read) as bytes,
        max(duration_ms) as longest_ms
  by source_ip
| sort connections desc
| limit 50
```

The SMTP surge alarm counts edge connections, not SMTP messages or recipients;
TLS and TCP proxying keep SMTP commands opaque to HAProxy. Tune
`mail_edge_smtp_connection_alarm_threshold` against the observed baseline and
keep the Mailu/Postfix recipient-volume alert enabled for message-level abuse.

Validate the pipeline on the instance through SSM:

```sh
sudo journalctl -t haproxy --since '-10 minutes'
sudo systemctl status mail-edge-haproxy-export amazon-cloudwatch-agent
sudo tail -n 20 /var/log/mail-edge/haproxy.log
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

Do not add HAProxy `send-proxy`/`send-proxy-v2` independently. Mailu must be
configured to expect the same header on that port, and current shared LAN
listeners make such a change unsafe without first separating traffic paths.

## Manual DNS Outputs

Use these outputs when public DNS is not fully managed by Terraform:

- `mail_edge_ses_dns_records_to_create`
- `mail_edge_dns_records_to_create`
- `mail_edge_certificate_dns01_cname`
- `mail_edge_recommended_public_security_dns_records`

For the public internet-facing zone, point the Cloudflare `A` record for
`mail_hostname` to `mail_edge_elastic_ip`, point the `MX` record for
`mail_domain` to `mail_hostname`, and point `autoconfig.<mail_domain>` plus
`autodiscover.<mail_domain>` at `mail_hostname`.

The security output currently contains only the apex SPF record because this
deployment's outbound path is unambiguously SES-only. DMARC and TLS-RPT require
real report destinations; MTA-STS additionally requires an HTTPS policy host
with a valid certificate. Do not publish placeholder destinations.

## Operational Notes

- Public `myrobertson.net` DNS is currently delegated to Cloudflare. The
  AD-backed DNS provider in this root is split-horizon/internal only and is
  disabled by default for mail records.
- The Elastic IP, SES domain identity, SES DKIM configuration, SES MAIL FROM
  configuration, SES verification, and SES SMTP IAM credentials are protected by
  Terraform `prevent_destroy` lifecycle rules.
- The public Mailu certificate uses direct Cloudflare DNS-01 for
  `mail.myrobertson.net`. Any `_acme-challenge` CNAME created here is for
  optional split-horizon/internal DNS only.
- AWS commonly throttles outbound public port `25` from EC2 by default. Use SES
  SMTP on `587` or `465` for outbound mail.
- SES may still require sandbox removal, identity verification, or other
  account-side approval before production sending is available.
- Terraform can manage Elastic IP reverse DNS with
  `configure_eip_reverse_dns = true` only when the matching forward `A` record
  is also managed through Route53.

## Related Documents

- [Mail edge design](../design/mail-edge.md)
- [mail_edge component README](../../terraform/mail_edge/README.md)
- [Terraform root](../../terraform/README.md)
