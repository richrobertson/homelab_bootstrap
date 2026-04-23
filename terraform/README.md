# Terraform Mail Edge

This Terraform root now includes an optional AWS mail edge for a home-hosted Mailu deployment.

## Architecture

```
Internet
  |
  v
AWS Elastic IP
  |
  v
Small EC2 instance
  - Security group opens SMTP, IMAPS, POP3S, web, and WireGuard
  - WireGuard tunnel to home
  - HAProxy in TCP mode forwards 25/80/443/465/587/993/995/4190
  |
  v
Home Mailu ingress/front container

Outbound path:
Mailu/Postfix -> Amazon SES SMTP endpoint on 465 or 587
```

SES is outbound-only in this design. Inbound mail still lands on Mailu through the EC2 edge and WireGuard tunnel.

## What Gets Deployed

- One small EC2 instance, default `t4g.nano`
- One Elastic IP attached to the instance
- One security group with public ingress on TCP `25`, `80`, `443`, `465`, `587`, `993`, `995`, `4190` and UDP `51820`
- Optional dedicated VPC, public subnet, IGW, and route table if you do not supply an existing `subnet_id`
- Optional SSM Session Manager IAM role/profile for instance access
- WireGuard and HAProxy bootstrap via EC2 `user_data`
- SES domain identity, DKIM, custom MAIL FROM domain, and SMTP IAM credentials
- Optional Route53 automation for SES DNS records and public mail `A`/`MX` records
- Optional Elastic IP reverse DNS using Terraform when the forward `A` record is also managed here

## Required Inputs

Enable the feature with `mail_edge_enabled = true`, then set at least:

- `mail_domain`
- `home_wireguard_peer_public_key`
- `wireguard_ec2_private_key`
- `wireguard_ec2_public_key`

Generate the EC2 WireGuard keypair before applying. This module expects both halves explicitly so it can bootstrap the instance and render the home peer config without depending on a local shell helper during Terraform runs.

Common inputs and defaults:

| Variable | Default | Notes |
| --- | --- | --- |
| `aws_region` | derived from existing S3 region logic | Sets EC2, SES, and EIP region |
| `name_prefix` | workspace-derived | Prefix for AWS resource names |
| `tags` | `{}` | Extra AWS tags |
| `mail_edge_enabled` | `false` | Creates the AWS mail edge only when enabled |
| `create_vpc` | `true` | Creates a tiny dedicated VPC/public subnet when true |
| `vpc_id` / `subnet_id` | `null` | Reuse an existing public subnet when `create_vpc = false` |
| `admin_cidr_blocks` | `[]` | SSH is only opened to these CIDRs and only when `key_name` is set |
| `instance_type` | `t4g.nano` | Low-cost default |
| `key_name` | `null` | Optional EC2 key pair for SSH |
| `enable_ssm_session_manager` | `true` | Attaches `AmazonSSMManagedInstanceCore` |
| `wireguard_listen_port` | `51820` | Public UDP WireGuard port on the EC2 edge |
| `home_mailu_tunnel_ip` | second host in `wireguard_tunnel_cidr` | Target IP for HAProxy backends |
| `home_wireguard_peer_public_key` | required | Home peer public key |
| `wireguard_ec2_private_key` | required | EC2 WireGuard private key, stored as a sensitive Terraform value |
| `wireguard_ec2_public_key` | required | EC2 WireGuard public key for the home peer config |
| `wireguard_home_allowed_ips` | `["<home_mailu_tunnel_ip>/32"]` | Expand this if the home peer routes a larger subnet |
| `wireguard_tunnel_cidr` | `10.77.0.0/30` | Point-to-point tunnel CIDR |
| `mail_domain` | required | SES identity domain and inbound MX domain |
| `mail_hostname` | `mail.<mail_domain>` | Public host for inbound `A` and MX target |
| `route53_zone_id` | `null` | Enables Route53 automation when set |
| `enable_ses` | `true` | Provisions outbound SES resources |
| `manage_ses_route53_records` | `true` | Auto-creates SES TXT/CNAME/MX/TXT records when `route53_zone_id` is set |
| `manage_public_mail_dns_records` | `false` | Auto-creates public inbound `A` and `MX` records when `route53_zone_id` is set |
| `manage_authoritative_mail_dns_records` | `false` | Creates split-horizon/internal `A` and `MX` records in AD-backed `myrobertson.net` DNS |
| `manage_authoritative_ses_dns_records` | `false` | Creates split-horizon/internal SES verification, DKIM, and MAIL FROM records in AD-backed `myrobertson.net` DNS |
| `manage_mail_certificate_dns01_cname` | `false` | Creates a split-horizon/internal `_acme-challenge` CNAME in AD-backed `myrobertson.net` DNS |
| `mail_certificate_dns01_delegate_zone` | `myrobertson.com` | Existing Cloudflare-managed zone used for the delegated ACME DNS-01 target |
| `mail_certificate_dns01_delegate_record_name` | derived from `mail_hostname` | Optional override for the delegated ACME target record name |
| `wait_for_ses_domain_verification` | `true` | Waits for SES verification when DNS is managed here |
| `ses_mail_from_subdomain` | `bounce` | Uses a separate MAIL FROM domain by default |
| `configure_eip_reverse_dns` | `false` | Attempts Terraform-managed EIP reverse DNS when the forward `A` record is also managed here |

## DNS Automation

Automatic when `route53_zone_id` is set:

- SES domain verification TXT
- SES DKIM CNAMEs
- SES MAIL FROM MX and SPF TXT when `manage_ses_route53_records = true`
- Public inbound `A` and `MX` when `manage_public_mail_dns_records = true`

Automatic in split-horizon/internal `myrobertson.net` DNS when explicitly enabled:

- Inbound `A` and `MX` when `manage_authoritative_mail_dns_records = true`
- SES verification, DKIM, and MAIL FROM records when `manage_authoritative_ses_dns_records = true`
- Split-horizon/internal `_acme-challenge` CNAME for `mail_hostname` when `manage_mail_certificate_dns01_cname = true`

Manual otherwise:

- Use `mail_edge_ses_dns_records_to_create`
- Use `mail_edge_dns_records_to_create`
- Use `mail_edge_certificate_dns01_cname` only if you intentionally mirror the ACME alias internally

For the public internet-facing zone, point your Cloudflare `A` record for `mail_hostname` to `mail_edge_elastic_ip`, and point the `MX` record for `mail_domain` to `mail_hostname`.

## Mailu Vault Integration

For the prod cluster Mailu overlay in `homelab_flux`, Terraform also seeds Vault paths that Flux consumes through Vault Secrets Operator:

- `secret/mailu/prod/app`
- `secret/mailu/prod/ses-relay`
- `secret/mailu/prod/config`

`secret/mailu/prod/app` contains the Mailu secret key, the generated `admin@<mail_domain>` bootstrap password, and PostgreSQL credentials. `secret/mailu/prod/ses-relay` contains the SES SMTP username and password. `secret/mailu/prod/config` contains a small `values.yaml` fragment that sets the SES relay hostname for the Helm release.

The prod Mailu overlay expects the home-side Mailu Service IP to be `10.31.0.73`, so set:

```hcl
home_mailu_tunnel_ip       = "10.31.0.73"
wireguard_home_allowed_ips = ["10.31.0.73/32"]
```

if your home WireGuard peer is routing only the Mailu Service IP across the tunnel.

## Post-Apply Mailu Steps

1. Bring up the EC2 edge and confirm the WireGuard endpoint from `mail_edge_wireguard_endpoint`.
2. Build the home peer config from `mail_edge_wireguard_home_peer_config`, add your home private key, and start the home WireGuard peer.
3. Make sure the home peer can route traffic for `home_mailu_tunnel_ip` to your Mailu front-end or ingress.
4. Confirm that Mailu is listening for the forwarded ports on the home-side target IP.
5. Point public DNS `A` and `MX` records if you did not enable either Route53 or authoritative DNS automation.
6. Reconcile the Mailu Flux overlay after the Vault secrets appear so the cluster picks up the relay credentials.

## Mailu Outbound Relay Through SES

Mailu supports a Postfix smarthost via `RELAYHOST`, `RELAYUSER`, and `RELAYPASSWORD`.

Recommended baseline:

```dotenv
RELAYHOST=[email-smtp.<aws-region>.amazonaws.com]:587
RELAYUSER=<mail_edge_ses_smtp_username>
RELAYPASSWORD=<mail_edge_ses_smtp_password>
OUTBOUND_TLS_LEVEL=encrypt
```

You can also use port `465` if you prefer TLS wrapper instead of STARTTLS. The Terraform output `mail_edge_ses_smtp_endpoint` gives the hostname.

## Home-Side WireGuard Notes

- If Mailu itself terminates WireGuard, `home_mailu_tunnel_ip` can be the Mailu host’s tunnel IP.
- If another home host terminates WireGuard and forwards into your cluster, set `home_mailu_tunnel_ip` to the IP that HAProxy should target over the tunnel.
- If that home peer routes more than a single host, widen `wireguard_home_allowed_ips` accordingly so the EC2 peer knows which prefixes belong across the tunnel.

## Inbound vs Outbound Flow

- Inbound mail and web traffic: public internet -> AWS Elastic IP -> EC2 security group -> HAProxy TCP frontend -> WireGuard tunnel -> home Mailu front-end
- Outbound mail: Mailu/Postfix -> SES SMTP endpoint -> recipient mail servers

## Reverse DNS

Terraform can manage Elastic IP reverse DNS with `configure_eip_reverse_dns = true` only when the matching forward `A` record is also managed here through Route53. This avoids creating a broken PTR request without the required forward record.

If your public DNS is managed elsewhere, add the forward `A` record first and then configure reverse DNS manually in the AWS console or CLI. AWS requires the forward `A` record to exist before the PTR update.

## Operational Notes

- Public `myrobertson.net` DNS is currently delegated to Cloudflare. The AD-backed DNS provider in this repo is split-horizon/internal only and is disabled by default for mail records.
- The public Mailu certificate uses direct Cloudflare DNS-01 for `mail.myrobertson.net`. Any `_acme-challenge` CNAME created by this Terraform root is for optional split-horizon/internal DNS only.
- AWS commonly throttles outbound public port `25` from EC2 by default. Use SES SMTP on `587` or `465` for outbound mail instead of trying to deliver directly from the instance.
- SES may still require sandbox removal, identity verification, or other console/account-side approval before production sending is available.
- Inbound port `25` still depends on the EC2 security group, subnet routing, NACLs, and the instance services coming up correctly.
- AWS recommends that a custom MAIL FROM domain not be reused as the same host that receives mail, so this implementation defaults `ses_mail_from_subdomain` to `bounce` rather than reusing `mail`.
