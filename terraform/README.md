# Terraform Bootstrap Root

This Terraform root creates the bootstrapped substrate and overlay needed before
Flux can manage the cluster. It is the executable entry point for Proxmox SDN,
Talos VMs, Kubernetes bootstrap, Vault integration, Flux bootstrap, Talos etcd
backup wiring, and the optional AWS Mailu edge.

## Start Here

- [Repository overview](../readme.md) - where this root fits in the wider
  homelab stack.
- [Docs index](../docs/README.md) - design docs, runbooks, and component map.
- [Bootstrap architecture](../docs/design/bootstrap-architecture.md) - full
  substrate and overlay walkthrough.
- [Environment model](../docs/design/environment-model.md) - workspace-driven
  environment selection.
- [Common Terraform operations](../docs/runbooks/common-terraform-operations.md)
  - init, workspace selection, plan, apply, context export, and cluster
  recreation.

## Execution Flow

```text
main.tf
  |
  +--> substrate/          production-only PostgreSQL and PowerDNS VMs
  +--> networking/         Proxmox EVPN/VXLAN zones, VNets, subnets, DNS zones
  +--> kubernetes/         Talos VMs, Talos bootstrap, Vault, cert-manager auth
  +--> modules/flux        Flux bootstrap into homelab_flux
  +--> mail_edge/          optional AWS edge for Mailu
  +--> *_backup*.tf        S3 bucket and Vault config for Talos etcd backups
  +--> mailu_*.tf          Vault secrets for the Flux-managed Mailu overlay
```

## Component READMEs

- [substrate](substrate/README.md) - production-only PostgreSQL and PowerDNS
  services.
- [networking](networking/README.md) - Proxmox SDN EVPN/VXLAN overlay.
- [kubernetes](kubernetes/README.md) - cluster composition across nodes, Talos,
  Vault, and certificates.
- [kubernetes/nodes](kubernetes/nodes/README.md) - Proxmox Talos VM placement
  and DNS records.
- [kubernetes/talos](kubernetes/talos/README.md) - Talos machine config,
  bootstrap, health, kubeconfig, and talosconfig.
- [kubernetes/vault_auth_backend](kubernetes/vault_auth_backend/README.md) -
  Vault Kubernetes auth backend.
- [kubernetes/vault_secret_backend](kubernetes/vault_secret_backend/README.md)
  - Vault Kubernetes secrets engine and Vault Secrets Operator role.
- [kubernetes/certs](kubernetes/certs/README.md) - cert-manager Vault PKI
  policy and auth role.
- [modules/flux](modules/flux/README.md) - Flux bootstrap handoff to
  `homelab_flux`.
- [mail_edge](mail_edge/README.md) - optional AWS Mailu edge.

For the same list grouped by dependency and ownership, see the
[component index](../docs/components/README.md).

## Design Documents

- [Bootstrap architecture](../docs/design/bootstrap-architecture.md)
- [Environment model](../docs/design/environment-model.md)
- [Mail edge design](../docs/design/mail-edge.md)

## Operational Runbooks

- [Common Terraform operations](../docs/runbooks/common-terraform-operations.md)
- [Talos etcd backups](../docs/runbooks/talos-etcd-backups.md)
- [GPU worker enablement](../docs/runbooks/gpu-worker-enablement.md)
- [Mail edge operations](../docs/runbooks/mail-edge-operations.md)

## Key Terraform Files

- [main.tf](main.tf) - root module composition.
- [environment.tf](environment.tf) - workspace-specific environment model.
- [providers.tf](providers.tf) - provider configuration and credential wiring.
- [data.tf](data.tf) - Vault-backed bootstrap inputs.
- [outputs.tf](outputs.tf) - kubeconfig, talosconfig, mail edge, and Mailu
  outputs.
- [mail_edge.tf](mail_edge.tf) - optional AWS Mailu edge module call.
- [mailu_vault_secrets.tf](mailu_vault_secrets.tf) - Mailu Vault secret seeding.
- [talos_etcd_backup_bucket.tf](talos_etcd_backup_bucket.tf) - shared S3 backup
  bucket.
- [talos_backup_vault_secret.tf](talos_backup_vault_secret.tf) - per-cluster
  backup config written to Vault.

## Provider Responsibilities

- `proxmox` creates SDN resources, downloads Talos images, and creates VMs.
- `dns` manages AD-backed DNS zones and records through RFC2136/GSS-TSIG.
- `talos` applies Talos machine config, bootstraps the cluster, and exports
  kubeconfig/talosconfig.
- `vault` reads bootstrap credentials and creates cluster auth, secret, PKI, and
  application secret material.
- `flux` installs Flux into the new cluster and points it at
  `richrobertson/homelab_flux`.
- `github` reads the Flux repository metadata used during bootstrap.
- `aws` creates the optional Mailu edge and shared Talos etcd backup bucket.
- `microsoftadcs` is configured for Windows CA integration.

Most provider credentials come from Vault paths in [data.tf](data.tf).
