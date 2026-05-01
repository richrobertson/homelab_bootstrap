# Email Canary Design

The email canary continuously verifies that production mail can be sent through
SES and delivered into Mailu/Dovecot. It is part of the AWS mail edge design,
but it is separated here because its purpose is detection and alerting rather
than mail transport.

## Goals

- Run automatically every five minutes.
- Send a unique SES probe message.
- Verify mailbox delivery through IMAP.
- Alert a cellphone by SMS when send or delivery checks fail.
- Exercise the real Mailu path into Kubernetes-hosted Dovecot folders.

## Architecture

```text
EventBridge schedule, rate(5 minutes)
  |
  v
AWS Lambda: prod-mailu-edge-email-canary
  |
  +--> SES SendEmail
  |
  +--> IMAP poll for unique subject/token
  |
  +--> SNS topic -> SMS subscription
```

The Lambda supports multiple named probes in one invocation. The current design
uses two probes:

- `external`: a general SES delivery probe.
- `mailu-dovecot`: verifies delivery all the way into the Mailu Dovecot IMAP
  folder.

## Mailu Delivery Path

The Mailu probe intentionally uses the public mail hostname for IMAP so the
check follows the real external edge:

```text
Lambda -> SES -> public MX -> AWS mail edge -> WireGuard
  -> mailu-front-ext on 10.31.0.73 -> Mailu/Dovecot -> IMAP INBOX
```

Using the public hostname avoids a false-positive internal shortcut where IMAP
works but the AWS edge, WireGuard path, Mailu front service, or Dovecot delivery
chain is broken.

## Secrets

The SMS destination is stored in Vault:

```text
secret/mailu/prod/email-canary-alerts
  phone_number
```

IMAP credentials are stored in AWS Secrets Manager in the mail edge region. The
secret contains JSON with the Dovecot host, username, password, folder, port,
and TLS mode.

The Lambda IAM policy allows:

- SES send actions.
- SNS publish to the canary alert topic.
- Secrets Manager read access to the configured IMAP secret.
- CloudWatch Logs writes for the canary log group.

## Failure Semantics

The Lambda alerts when:

- SES rejects the send.
- IMAP credentials cannot be loaded.
- IMAP login, folder selection, or message search fails.
- The unique probe message does not appear before the timeout.

Delivery misses are intentionally broad signals. They can indicate recipient
reputation rejection, filtering, DNS trouble, Mailu ingress failure, Dovecot
delivery failure, or IMAP access failure. The probe name in the alert narrows
the failed path.

## Terraform State

Terraform configuration for the canary lives in
[terraform/mail_edge](../../terraform/mail_edge/README.md). The live canary was
deployed with the same resource names while broader Terraform state issues are
resolved, because a full root plan currently includes unrelated Proxmox and
Flux changes.

Once the root plan is clean, Terraform should own the Lambda, SNS, EventBridge,
CloudWatch Logs, and IAM resources directly.

## Related Documents

- [Mail edge design](mail-edge.md)
- [Mail edge operations](../runbooks/mail-edge-operations.md)
- [mail_edge component README](../../terraform/mail_edge/README.md)
