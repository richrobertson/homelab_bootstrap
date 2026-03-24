# Kubernetes Stack

Manages Kubernetes-related infrastructure, Talos bootstrapping, certificates, and Vault integrations.

## What This Stack Manages

- Talos cluster bootstrap orchestration and machine configuration wiring.
- Kubernetes-facing certificate resources and node-related integration.
- Vault authentication and secret backend resources connected to Kubernetes flows.

## When To Edit

- Update Talos bootstrap behavior, cluster endpoint assumptions, or node bootstrap sequencing.
- Update certificate or Vault integration behavior consumed by cluster components.
- Add Kubernetes stack resources that should not live in a reusable module.

## Child Modules

- [certs](certs/README.md)
- [nodes](nodes/README.md)
- [talos](talos/README.md)
- [talos_vm](talos_vm/README.md)
- [vault_auth_backend](vault_auth_backend/README.md)
- [vault_pki_secret_backend](vault_pki_secret_backend/README.md)
- [vault_secret_backend](vault_secret_backend/README.md)

## Navigation

- [Terraform Index](../README.md)

