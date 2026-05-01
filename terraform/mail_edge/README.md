# Mail Edge Component

The mail edge module creates the optional AWS ingress and SES relay path for a
home-hosted Mailu deployment.

## Responsibilities

- Create a small EC2 instance, Elastic IP, and security group.
- Optionally create a dedicated VPC, public subnet, internet gateway, and route
  table.
- Optionally attach SSM Session Manager access.
- Configure WireGuard and HAProxy with EC2 `user_data`.
- Create SES identity, DKIM, custom MAIL FROM, and SMTP credentials.
- Optionally create a Lambda email canary that runs every five minutes, sends a
  unique SES probe, checks a mailbox through IMAP, and alerts through SNS/SMS
  when sending or delivery is delayed or rejected.
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
```

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
