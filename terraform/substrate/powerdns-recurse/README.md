# PowerDNS Recursive Substrate

This child module creates the substrate recursive DNS server used by bootstrap
environments.

## Responsibilities

- Create the recursive DNS VM.
- Provide the recursive DNS endpoint exposed as `ns1.myrobertson.net`.
- Depend on the substrate database layer before provisioning.

## Parent Component

- [substrate](../README.md)

## Related Documents

- [Bootstrap architecture](../../../docs/design/bootstrap-architecture.md#substrate)
- [Component index](../../../docs/components/README.md#substrate)
