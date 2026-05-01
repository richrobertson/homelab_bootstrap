# Vault PKI Secret Backend Component

This component manages the Vault PKI backend and role used by cluster
certificate issuance.

## Responsibilities

- Configure the Vault PKI mount for the cluster.
- Configure the `cluster_ssl_certs` role.
- Apply environment-specific certificate constraints from
  [environment.tf](../../environment.tf).

## Consumers

- [certs](../certs/README.md) creates cert-manager policy and auth role entries
  for this backend.
- Flux-managed cert-manager resources use the resulting Vault role through
  Kubernetes auth.

## Related Documents

- [Environment model](../../../docs/design/environment-model.md#vault-pki-policy)
- [kubernetes parent](../README.md)
- [certs](../certs/README.md)
- [Component index](../../../docs/components/README.md#kubernetes)
