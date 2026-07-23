# Mail Domain Hardening

Public `myrobertson.net` DNS is hosted by Cloudflare. The Terraform root manages
the public mail-policy TXT records through `cloudflare_mail_dns.tf`; its
separate DNS provider remains split-horizon/internal.

## Verified Public State

Checked through Cloudflare's public resolver on 2026-07-23:

- `myrobertson.net MX 10 mail.myrobertson.net.`
- `mail.myrobertson.net A 44.237.126.101`
- `bounce.myrobertson.net MX 10 feedback-smtp.us-west-2.amazonses.com.`
- `bounce.myrobertson.net TXT "v=spf1 include:amazonses.com ~all"`
- `myrobertson.net TXT "v=spf1 include:amazonses.com -all"`
- `_dmarc.myrobertson.net TXT "v=DMARC1; p=quarantine; rua=mailto:reports@myrobertson.net; adkim=s; aspf=r; fo=1; pct=25"`
- `_mta-sts.myrobertson.net TXT "v=STSv1; id=20260723T194500Z;"`
- `_smtp._tls.myrobertson.net TXT "v=TLSRPTv1; rua=mailto:reports@myrobertson.net"`
- `mta-sts.myrobertson.net` serves an enforced HTTPS policy for `mail.myrobertson.net`.

Re-run these checks immediately before any DNS change:

```sh
dig @1.1.1.1 +short myrobertson.net MX
dig @1.1.1.1 +short myrobertson.net TXT
dig @1.1.1.1 +short _dmarc.myrobertson.net TXT
dig @1.1.1.1 +short _mta-sts.myrobertson.net TXT
dig @1.1.1.1 +short _smtp._tls.myrobertson.net TXT
curl -fsS https://mta-sts.myrobertson.net/.well-known/mta-sts.txt
```

## SPF Policy

The architecture requires all outbound Mailu delivery to use Amazon SES. The
Terraform output `mail_edge_recommended_public_security_dns_records` therefore
emits the one public policy whose sender and value are already established:

```text
myrobertson.net. 300 IN TXT "v=spf1 include:amazonses.com -all"
```

Keep the existing dedicated `bounce.myrobertson.net` SES MAIL FROM records and
review this policy before adding any other outbound service.

## DMARC Enforcement

The dedicated `reports@myrobertson.net` mailbox receives aggregate reports. The
GitOps-managed mail report listener consumes that mailbox and exposes report
health to Prometheus and Alertmanager.
SES signs with aligned DKIM. Its custom MAIL FROM domain is the
`bounce.myrobertson.net` subdomain, so SPF uses relaxed alignment while DKIM
remains strict. The first enforcement stage is:

```text
_dmarc.myrobertson.net. 300 IN TXT "v=DMARC1; p=quarantine; rua=mailto:reports@myrobertson.net; adkim=s; aspf=r; fo=1; pct=25"
```

Review aligned SPF/DKIM results for at least one week, then progress through
`p=quarantine; pct=100` and finally `p=reject; pct=100`.

SMTP TLS reports use the monitored reports mailbox:

```text
_smtp._tls.myrobertson.net. 300 IN TXT "v=TLSRPTv1; rua=mailto:reports@myrobertson.net"
```

MTA-STS is enforced at this HTTPS origin:

```text
https://mta-sts.myrobertson.net/.well-known/mta-sts.txt
```

Change the `_mta-sts` policy ID whenever the HTTPS policy changes.

## Validation Order

1. Confirm SES DKIM and custom MAIL FROM remain successful.
2. Verify the apex SPF, DMARC, MTA-STS, and TLS-RPT records publicly.
3. Review DMARC aggregate reports during each enforcement stage.
4. Progress to `p=quarantine; pct=100`, then `p=reject; pct=100`.
5. Keep the MTA-STS HTTPS policy and DNS policy ID synchronized.
