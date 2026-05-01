# Substrate Component

The substrate module creates the production-only services that the rest of the
bootstrap depends on before Kubernetes exists.

## Responsibilities

- Download Debian cloud images into Proxmox storage.
- Create the PostgreSQL VM `subdb1` at `192.168.7.200`.
- Create the PowerDNS recursive DNS VM used as `ns1.myrobertson.net`.
- Create the PowerDNS authoritative DNS VM used as `subns.myrobertson.net`.

## Environment Behavior

The root module only creates this component in production:

```hcl
count = local.env.environment_name == "prod" ? 1 : 0
```

Staging and development reuse the production substrate DNS endpoints instead of
creating their own substrate VMs.

## Child Components

- [postgresql-database](postgresql-database) - PostgreSQL VM.
- [powerdns-recurse](powerdns-recurse) - recursive DNS VM.
- [powerdns-auth](powerdns-auth) - authoritative DNS VM.

## Related Documents

- [Bootstrap architecture](../../docs/design/bootstrap-architecture.md#substrate)
- [Environment model](../../docs/design/environment-model.md)
- [Terraform root](../README.md)
- [Component index](../../docs/components/README.md#substrate)
