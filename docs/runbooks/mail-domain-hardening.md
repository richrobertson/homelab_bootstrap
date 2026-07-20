# Mail Domain Hardening

Public `myrobertson.net` DNS is hosted by Cloudflare and is not managed by this
Terraform root. The DNS provider configured here is split-horizon/internal, so
the records below must be reviewed and published in Cloudflare separately.

## Verified Public State

Checked through Cloudflare's public resolver on 2026-07-20:

- `myrobertson.net MX 10 mail.myrobertson.net.`
- `mail.myrobertson.net A 44.237.126.101`
- `bounce.myrobertson.net MX 10 feedback-smtp.us-west-2.amazonses.com.`
- `bounce.myrobertson.net TXT "v=spf1 include:amazonses.com ~all"`
- No apex SPF, `_dmarc`, `_mta-sts`, or `_smtp._tls` TXT answer.
- `mta-sts.myrobertson.net` does not resolve and no HTTPS policy is hosted.

Re-run these checks immediately before any DNS change:

```sh
dig @1.1.1.1 +short myrobertson.net MX
dig @1.1.1.1 +short myrobertson.net TXT
dig @1.1.1.1 +short _dmarc.myrobertson.net TXT
dig @1.1.1.1 +short _mta-sts.myrobertson.net TXT
dig @1.1.1.1 +short _smtp._tls.myrobertson.net TXT
curl -fsS https://mta-sts.myrobertson.net/.well-known/mta-sts.txt
```

## Ready Record

The architecture requires all outbound Mailu delivery to use Amazon SES. The
Terraform output `mail_edge_recommended_public_security_dns_records` therefore
emits the one public policy whose sender and value are already established:

```text
myrobertson.net. 300 IN TXT "v=spf1 include:amazonses.com -all"
```

Publish only after confirming there are no undiscovered services using a
different envelope sender path. Keep the existing dedicated
`bounce.myrobertson.net` SES MAIL FROM records.

## Staged Records With Blockers

DMARC is blocked on a confirmed aggregate-report mailbox or HTTPS report
collector. After provisioning `dmarc-reports@myrobertson.net`, start with:

```text
_dmarc.myrobertson.net. 300 IN TXT "v=DMARC1; p=none; rua=mailto:dmarc-reports@myrobertson.net; adkim=r; aspf=r; pct=100"
```

Review aligned SPF/DKIM results for at least two weeks, then progress through
`p=quarantine; pct=25`, higher percentages, and finally `p=reject; pct=100`.

SMTP TLS reporting is blocked on a confirmed report destination. After
provisioning `tls-reports@myrobertson.net`, publish:

```text
_smtp._tls.myrobertson.net. 300 IN TXT "v=TLSRPTv1; rua=mailto:tls-reports@myrobertson.net"
```

MTA-STS is blocked on a Cloudflare DNS record plus an HTTPS origin serving a
valid certificate and this exact path:

```text
https://mta-sts.myrobertson.net/.well-known/mta-sts.txt
```

Start the policy in testing mode:

```text
version: STSv1
mode: testing
mx: mail.myrobertson.net
max_age: 86400
```

After the HTTPS policy is live and verified, publish
`_mta-sts.myrobertson.net TXT "v=STSv1; id=<deployment-timestamp>"`. Change the
ID whenever the policy changes. Review TLS-RPT results before switching to
`mode: enforce` and a longer `max_age`.

## Validation Order

1. Confirm SES DKIM is enabled and passing on real outbound mail.
2. Publish and verify the apex SPF record.
3. Provision report destinations and deploy DMARC with `p=none` plus TLS-RPT.
4. Deploy and validate the HTTPS MTA-STS policy in testing mode.
5. Observe reports, then progressively enforce DMARC and MTA-STS.
