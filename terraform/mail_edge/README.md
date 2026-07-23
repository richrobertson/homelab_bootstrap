# Mail Edge Component

The mail edge module creates the optional AWS ingress and SES relay path for a
home-hosted Mailu deployment.

## Responsibilities

- Create a small EC2 instance, Elastic IP, and security group.
- Optionally create a dedicated VPC, public subnet, internet gateway, and route
  table.
- Optionally attach SSM Session Manager access.
- Configure WireGuard and HAProxy with EC2 `user_data`.
- Persist HAProxy journald records locally, export structured connection logs to
  a retention-managed CloudWatch Logs group, and alarm on SMTP connection
  surges, unavailable backends, and EC2 status-check failures.
- Create SES identity, DKIM, custom MAIL FROM, and SMTP credentials.
- Create SES event publishing, failure-event SNS delivery, and CloudWatch
  alarms for account send volume, bounce reputation, and complaint reputation.
- Optionally create a Lambda email canary that runs every fifteen minutes, sends a
  unique SES probe, checks a mailbox through IMAP, and alerts through SNS/SMS
  when sending or delivery is delayed or rejected. It publishes per-probe
  `SendAccepted`, `Success`, `Failure`, and `DeliveryLatencySeconds` metrics in
  the `Mailu/EmailCanary` namespace and alarms after two missed invocation
  windows.
- Retain the protected read-only Grafana CloudWatch IAM identity whose
  sensitive access key is synchronized to Vault by the Terraform root.
- Optionally install an edge-host RCPT-only relay-policy canary that exercises
  the WireGuard-to-home Postfix path, emits CloudWatch heartbeats, and never
  sends `DATA`.
- Optionally create Route53 records and Elastic IP reverse DNS.

## Destroy Guardrails

The stable AWS public IP, SES sending identity, and Grafana CloudWatch reader
are protected with Terraform `prevent_destroy` lifecycle rules. Plans that
would destroy the Elastic IP, SES domain identity, DKIM configuration, MAIL
FROM configuration, SES verification, SES SMTP IAM credentials, or Grafana
reader credentials should fail rather than silently breaking mail or monitoring.

## Traffic Flow

```text
Inbound:
Internet -> AWS Elastic IP -> HAProxy -> WireGuard -> home Mailu front end

Outbound:
Mailu/Postfix -> SES SMTP endpoint -> recipient mail servers

External canary:
EventBridge -> Lambda -> SES -> external recipient mailbox -> IMAP check -> SNS/SMS alert

Mailu Dovecot canary:
EventBridge -> Lambda -> SES -> public MX -> AWS edge -> WireGuard -> Mailu -> Dovecot IMAP -> SNS/SMS alert

Open-relay canary:
systemd timer on AWS edge -> WireGuard -> home Mailu:25 -> EHLO/MAIL FROM/RCPT TO -> RSET/QUIT -> CloudWatch/SNS alert
```

## SES Monitoring

SES monitoring is enabled by default when SES is enabled. It creates:

- A configuration set with CloudWatch destinations for send, delivery, bounce,
  complaint, reject, and rendering-failure events.
- An SNS destination for bounce, complaint, reject, and rendering-failure
  events. No subscription is created automatically so an operator can attach a
  queue, Lambda, HTTPS endpoint, or other consumer without sending one SMS per
  event.
- Account-level CloudWatch alarms for a five-minute recipient-send surge, bounce
  reputation, and complaint reputation. These alarms work independently of the
  configuration set and publish to a separate alert topic. The existing canary
  SMS phone number is subscribed when configured.

The configuration set does not enable Virtual Deliverability Manager or
configuration-set reputation export. Fine-grained CloudWatch event metrics can
still incur normal CloudWatch custom-metric charges.

Terraform associates the configuration set as the SES identity default, so
Mailu SMTP traffic uses the event destinations without requiring a custom
header. The `ses_configuration_set_header` output remains available for an
explicit sender override. After apply, verify new messages appear with the
`ses:configuration-set` CloudWatch dimension. The account-level alarms remain
independent of configuration-set event publishing.

Thresholds are configurable through `ses_send_volume_threshold`,
`ses_bounce_rate_threshold`, and `ses_complaint_rate_threshold`. The reputation
defaults are 4% bounce and 0.08% complaint, below AWS review levels of 5% and
0.1% respectively. SES can omit reputation datapoints during quiet periods, so
the bounce and complaint alarms retain their current state when data is missing.
This prevents an active reputation incident from appearing healthy solely due
to a missing datapoint; missing data while healthy does not independently alert.

## Email Canary

Set `enable_email_canary = true` and provide:

- `email_canary_from_address`: a verified SES sender address.
- `email_canary_to_address`: the mailbox that should receive the probe.
- `email_canary_imap_secret_arn`: a Secrets Manager secret containing JSON:

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

The root module reads the SMS destination from Vault path
`secret/mailu/prod/email-canary-alerts` by default. Store the number under the
`phone_number` key in E.164 format, for example `+15551234567`.

To verify delivery all the way into the Kubernetes-hosted Mailu Dovecot
mailbox, also set `enable_mailu_dovecot_canary = true` and provide:

- `mailu_dovecot_canary_to_address`: a Mailu-hosted recipient address.
- `mailu_dovecot_canary_imap_secret_arn`: a Secrets Manager secret for that
  Mailu mailbox.

For the Mailu Dovecot secret, use the public edge hostname so the probe
traverses the same external path as real mail:

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

## Edge Observability

`enable_cloudwatch_observability` defaults to `true`. Terraform creates the
log group and its retention policy, grants the EC2 role access only to streams
in that group, and uses an SSM State Manager association to configure existing
as well as newly created edge instances. AL2023 journald remains the local
source of truth; a cursor-backed exporter writes only HAProxy records to a
bounded file that CloudWatch Agent tails.

HAProxy connection records are JSON and include `source_ip`, `source_port`,
`frontend`, `backend`, duration, byte count, and termination state. They retain
the public address at the AWS edge even when WireGuard or Kubernetes later
SNATs the connection.

## Open-Relay Canary

Set `enable_open_relay_canary = true` to install a five-minute systemd timer on
the AWS mail-edge EC2 instance. The probe connects directly to
`effective_home_mailu_tunnel_ip:25` across WireGuard. The resulting connection
enters the home Mailu Service through the same Kubernetes SNAT and Postfix
`aws_edge_inbound_only` restriction class as production traffic forwarded by
the edge. In production, configure the target as the Mailu front ClusterIP
`10.109.196.109`, not the `10.31.0.73` LAN MetalLB VIP. Kubernetes then presents
the worker-2 CNI gateway `10.244.5.1` to Postfix.

The probe uses reserved `example.com` and `example.net` addresses. The expected
Postfix `5.7.1 Relay access denied` response is healthy, any 2xx response
(including 251/252) is critical, and any other 4xx/5xx, transport, or protocol
failure is indeterminate. Every attempt emits a JSON heartbeat to CloudWatch.
Separate alarms cover critical results, indeterminate results, and three
missing five-minute heartbeats. The SMTP state machine has no `DATA` command
and attempts only `RSET` and `QUIT` after RCPT.

This is intentionally a regression check for the incident path, not a truly
external open-relay test. It bypasses the public Elastic IP, security group,
public DNS, HAProxy listener, and TLS, and it originates only from the trusted
AWS edge. Retain an independent external SMTP monitor or controlled VPS probe
to cover those layers and source-dependent behavior from arbitrary internet
addresses.

## Root Integration

- [mail_edge.tf](../mail_edge.tf) calls this module.
- [authoritative_mail_dns.tf](../authoritative_mail_dns.tf) optionally manages
  split-horizon/internal DNS records.
- [mailu_vault_secrets.tf](../mailu_vault_secrets.tf) writes Mailu app and SES
  relay secrets for the Flux-managed Mailu overlay.
- [outputs.tf](../outputs.tf) exposes edge IPs, WireGuard config, DNS records,
  and SES SMTP credentials.

## Related Documents

- [Mail edge design](../../docs/design/mail-edge.md)
- [Mail edge operations](../../docs/runbooks/mail-edge-operations.md)
- [Terraform root](../README.md)
- [Component index](../../docs/components/README.md#edge-and-backups)
