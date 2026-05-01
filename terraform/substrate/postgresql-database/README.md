# PostgreSQL Database Substrate

This child module creates the substrate PostgreSQL VM.

## Responsibilities

- Create the VM named `subdb1`.
- Assign the production substrate address `192.168.7.200/32`.
- Attach the VM to VLAN `7` on bridge `vmbr1`.
- Use the substrate database password provided by Vault.

## Parent Component

- [substrate](../README.md)

## Related Documents

- [Bootstrap architecture](../../../docs/design/bootstrap-architecture.md#substrate)
- [Component index](../../../docs/components/README.md#substrate)
