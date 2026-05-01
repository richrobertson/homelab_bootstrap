# Kubernetes Component

The Kubernetes module composes Talos VM creation, Talos cluster bootstrap, Vault
integration, and certificate issuer wiring.

## Child Components

- [nodes](nodes/README.md) - creates Proxmox VMs and node DNS records.
- [talos](talos/README.md) - renders Talos config, applies it to nodes,
  bootstraps etcd, and exports kubeconfig/talosconfig.
- [vault_pki_secret_backend](vault_pki_secret_backend) - PKI backend used by the
  cluster certificate role.
- [vault_auth_backend](vault_auth_backend/README.md) - Kubernetes auth backend.
- [vault_secret_backend](vault_secret_backend/README.md) - Kubernetes secrets
  engine and Vault Secrets Operator role.
- [certs](certs/README.md) - cert-manager Vault policy and auth role.

## Input Sources

- Network bridges and subnets from [networking](../networking/README.md).
- Environment sizing, GPU, and PKI policy from
  [environment.tf](../environment.tf).
- DNS server references from either [substrate](../substrate/README.md) or the
  fixed production substrate endpoints.

## Outputs

The root exposes the generated cluster configs through:

- `kubeconfig`
- `talosconfig`

See [Common Terraform operations](../../docs/runbooks/common-terraform-operations.md#export-local-cluster-context)
for export commands.

## Related Documents

- [Bootstrap architecture](../../docs/design/bootstrap-architecture.md#kubernetes-overlay)
- [Environment model](../../docs/design/environment-model.md)
- [GPU worker enablement](../../docs/runbooks/gpu-worker-enablement.md)
- [Terraform root](../README.md)
- [Component index](../../docs/components/README.md#kubernetes)
