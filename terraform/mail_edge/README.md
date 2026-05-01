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
