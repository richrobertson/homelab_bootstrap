# Component Index

This index links each bootstrap component to its local README and nearby design
or runbook documents.

## Root Composition

- [terraform root](../../terraform/README.md) - root module index and provider
  responsibilities.
- [main.tf](../../terraform/main.tf) - composes substrate, networking,
  Kubernetes, Flux, and firewall placeholder modules.
- [environment model](../design/environment-model.md) - workspace-specific
  environment values.

## Substrate

- [substrate](../../terraform/substrate/README.md) - production-only substrate
  module.
- [postgresql-database](../../terraform/substrate/postgresql-database) -
  PostgreSQL VM used by substrate services.
- [powerdns-recurse](../../terraform/substrate/powerdns-recurse) - recursive DNS
  VM.
- [powerdns-auth](../../terraform/substrate/powerdns-auth) - authoritative DNS
  VM.
- Design: [Bootstrap architecture](../design/bootstrap-architecture.md#substrate)

## Networking

- [networking](../../terraform/networking/README.md) - Proxmox SDN EVPN/VXLAN,
  VNets, subnets, and environment DNS zones.
- Design: [Environment model](../design/environment-model.md#network-identity)

## Kubernetes

- [kubernetes](../../terraform/kubernetes/README.md) - module composition for
  nodes, Talos, Vault, and certificates.
- [nodes](../../terraform/kubernetes/nodes/README.md) - Proxmox Talos VMs and
  node DNS records.
- [talos](../../terraform/kubernetes/talos/README.md) - machine configuration,
  bootstrap, health checks, kubeconfig, and talosconfig.
- [vault_pki_secret_backend](../../terraform/kubernetes/vault_pki_secret_backend/README.md)
  - Vault PKI mount and certificate role.
- [vault_auth_backend](../../terraform/kubernetes/vault_auth_backend/README.md)
  - Vault Kubernetes auth.
- [vault_secret_backend](../../terraform/kubernetes/vault_secret_backend/README.md)
  - Vault Kubernetes secrets engine and Vault Secrets Operator role.
- [certs](../../terraform/kubernetes/certs/README.md) - cert-manager Vault PKI
  policy and auth role.
- Runbook: [GPU worker enablement](../runbooks/gpu-worker-enablement.md)

## GitOps Handoff

- [modules/flux](../../terraform/modules/flux/README.md) - Flux bootstrap into
  `richrobertson/homelab_flux`.
- Design: [Bootstrap architecture](../design/bootstrap-architecture.md#flux-handoff)

## Edge And Backups

- [mail_edge](../../terraform/mail_edge/README.md) - AWS Mailu edge.
- Design: [Mail edge design](../design/mail-edge.md)
- Runbook: [Mail edge operations](../runbooks/mail-edge-operations.md)
- Runbook: [Talos etcd backups](../runbooks/talos-etcd-backups.md)
