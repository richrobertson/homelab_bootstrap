# Vault Kubernetes Auth Backend Component

This component creates the Vault Kubernetes auth backend for a bootstrapped
cluster.

## Responsibilities

- Create a Vault auth backend at `<environment>-kubernetes`.
- Configure the backend with the Kubernetes API endpoint and cluster CA.
- Set the issuer to the Kubernetes cluster endpoint.

## Inputs

- `environment_name`
- `kubernetes_cluster_ca_certificate`
- `kubernetes_cluster_endpoint`

These values come from the parent [kubernetes component](../README.md) after the
[talos component](../talos/README.md) has produced client configuration.

## Consumers

- [vault_secret_backend](../vault_secret_backend/README.md) creates the
  Vault Secrets Operator auth role against this backend.
- [certs](../certs/README.md) creates the cert-manager auth role against this
  backend.

## Related Documents

- [Vault integration architecture](../../../docs/design/bootstrap-architecture.md#kubernetes-overlay)
- [kubernetes parent](../README.md)
- [Component index](../../../docs/components/README.md#kubernetes)
