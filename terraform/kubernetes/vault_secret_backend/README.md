# Vault Kubernetes Secrets Backend Component

This component configures Vault so in-cluster workloads can access Vault-backed
secret material through the Kubernetes auth flow.

## Responsibilities

- Create a Vault Kubernetes secrets engine at `<environment>-kubernetes`.
- Create the `vault-secrets-operator-role`.
- Create a Vault policy allowing auth, Kubernetes secrets engine, and KV secret
  access needed by Vault Secrets Operator.
- Bind the role to Vault Secrets Operator service accounts.

## Inputs

- Kubernetes API endpoint and CA from [talos](../talos/README.md).
- Kubernetes auth backend path from
  [vault_auth_backend](../vault_auth_backend/README.md).

## Consumers

- Flux-managed Vault Secrets Operator resources in `homelab_flux`.
- Bootstrap-seeded secrets such as Mailu and Talos backup configuration.

## Related Documents

- [kubernetes parent](../README.md)
- [Mail edge design](../../../docs/design/mail-edge.md#mailu-vault-secrets)
- [Talos etcd backups](../../../docs/runbooks/talos-etcd-backups.md)
- [Component index](../../../docs/components/README.md#kubernetes)
