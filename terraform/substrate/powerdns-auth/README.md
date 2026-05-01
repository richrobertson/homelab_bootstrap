# PowerDNS Authoritative Substrate

This child module creates the substrate authoritative DNS server used by
bootstrap environments and AD-backed DNS integration.

## Responsibilities

- Create the authoritative DNS VM.
- Provide the authoritative DNS endpoint exposed as `subns.myrobertson.net`.
- Depend on the recursive DNS layer before provisioning.

## Parent Component

- [substrate](../README.md)

## Related Documents

- [Bootstrap architecture](../../../docs/design/bootstrap-architecture.md#substrate)
- [Component index](../../../docs/components/README.md#substrate)
