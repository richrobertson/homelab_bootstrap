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
- Optionally create a Lambda email canary that runs every five minutes, sends a
  unique SES probe, checks a mailbox through IMAP, and alerts through SNS/SMS
  when sending or delivery is delayed or rejected.
- Optionally extend that Lambda with a public-MX open-relay canary that stops
  after `RCPT TO`, always resets the transaction, and never sends `DATA`.
- Optionally create Route53 records and Elastic IP reverse DNS.

## Destroy Guardrails

The stable AWS public IP and SES sending identity are protected with Terraform
`prevent_destroy` lifecycle rules. Plans that would destroy the Elastic IP, SES
domain identity, DKIM configuration, MAIL FROM configuration, SES verification,
or SES SMTP IAM credentials should fail rather than silently breaking inbound
mail, outbound relay, or DNS reputation.

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
EventBridge -> Lambda -> public MX:25 -> EHLO/MAIL FROM/RCPT TO -> RSET/QUIT -> SNS/SMS alert
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
0.1% respectively.

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

To check the unauthenticated public MX path for relaying, set
`enable_open_relay_canary = true`. The check uses reserved `example.com` and
`example.net` addresses, treats only a permanent 5xx response to `RCPT TO` as
healthy, and sends `RSET` then `QUIT` without ever entering `DATA`. Keep the
default port at 25; testing submission port 587 would not cover an MX relay
regression. Confirm that the Lambda account/region is permitted to make public
port-25 connections before enabling it, because AWS commonly throttles that
traffic. A timeout or 4xx response alerts as inconclusive rather than claiming
the relay is closed.

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
