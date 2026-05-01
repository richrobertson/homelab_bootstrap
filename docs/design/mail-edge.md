# Mail Edge Design

The optional mail edge provides a public AWS ingress point for a home-hosted
Mailu deployment. It is enabled with `mail_edge_enabled = true`.

## Architecture

```text
Internet
  |
  v
AWS Elastic IP
  |
  v
Small EC2 instance
  - Security group opens SMTP, submission, IMAP, POP3, web, ManageSieve, and WireGuard
  - WireGuard tunnel to home
  - HAProxy forwards mail ports and HTTPS over WireGuard
  - HAProxy redirects plain HTTP to HTTPS at the edge
  |
  v
Home Mailu ingress/front container

Outbound path:
Mailu/Postfix -> Amazon SES SMTP endpoint on 465 or 587
```

SES is the required production outbound relay in this design. Inbound mail lands
on Mailu through the EC2 edge and WireGuard tunnel.

The [email canary design](email-canary.md) adds continuous delivery checks on
top of this transport path.

## Terraform Scope

[terraform/mail_edge](../../terraform/mail_edge/README.md) creates:

- EC2 instance, Elastic IP, and security group.
- Optional dedicated VPC, public subnet, internet gateway, and route table.
- Optional SSM Session Manager IAM role/profile.
- WireGuard and HAProxy bootstrap through EC2 `user_data`.
- SES domain identity, DKIM, custom MAIL FROM domain, and SMTP IAM credentials.
- Optional Route53 DNS records and Elastic IP reverse DNS.

The stable Elastic IP and SES-related resources are protected with Terraform
`prevent_destroy` lifecycle rules so accidental module removal, `enable_ses =
false`, or destructive plans fail before breaking mail delivery.

The root files [mail_edge.tf](../../terraform/mail_edge.tf),
[authoritative_mail_dns.tf](../../terraform/authoritative_mail_dns.tf), and
[mailu_vault_secrets.tf](../../terraform/mailu_vault_secrets.tf) connect the
module to DNS and Vault.

## DNS Model

Public `myrobertson.net` DNS is currently delegated to Cloudflare. The
AD-backed DNS provider in this Terraform root is split-horizon/internal only and
is disabled by default for mail records.

Route53 automation can create:

- SES domain verification TXT.
- SES DKIM CNAMEs.
- SES MAIL FROM MX and SPF TXT.
- Public inbound `A` and `MX` records when explicitly enabled.

Internal authoritative DNS automation can create:

- Split-horizon inbound `A` and `MX`.
- Split-horizon SES verification, DKIM, and MAIL FROM records.
- Optional internal `_acme-challenge` CNAME.

## Mailu Vault Secrets

For the production Mailu overlay in `homelab_flux`, Terraform seeds:

- `secret/mailu/prod/app`
- `secret/mailu/prod/ses-relay`
- `secret/mailu/prod/config`

Those secrets are consumed by the Flux-managed Mailu deployment through Vault
Secrets Operator.

## Related Documents

- [mail_edge component README](../../terraform/mail_edge/README.md)
- [Email canary design](email-canary.md)
- [Mail edge operations](../runbooks/mail-edge-operations.md)
- [Bootstrap architecture](bootstrap-architecture.md)
