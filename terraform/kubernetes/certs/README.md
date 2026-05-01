# Certs Component

The certs component creates the Vault policy and Kubernetes auth role used by
cert-manager to request certificates from Vault PKI.

## Responsibilities

- Normalize the configured Vault PKI policy paths.
- Create the `<environment>-kubernetes-pki` Vault policy.
- Create the `vault-cert-issuer-role` Kubernetes auth backend role.
- Bind the role to `cert-manager` and `default` service accounts.

## Inputs

- `environment_name`
- `kubernetes_cluster_endpoint`
- `vault_kubernetes_auth_backend`
- `vault_pki_secret_backend_path`
- `vault_pki_policy_paths`

The environment-specific PKI policy paths come from
[environment.tf](../../environment.tf).

## Related Documents

- [Environment model](../../../docs/design/environment-model.md#vault-pki-policy)
- [kubernetes parent](../README.md)
- [vault_auth_backend](../vault_auth_backend/README.md)
- [Component index](../../../docs/components/README.md#kubernetes)
