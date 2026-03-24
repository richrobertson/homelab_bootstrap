# Reusable Terraform Modules

Manages reusable Terraform modules consumed by higher-level stacks in this repository.

## How To Use This Directory

- Put shared logic here when two or more stacks need the same behavior.
- Keep stack-specific orchestration out of these modules and in stack directories.
- Prefer small, composable modules with clear inputs and outputs.

## Module Catalog

- [certificate](certificate/README.md) — certificate lifecycle building block.
- [dns_record](dns_record/README.md) — shared DNS record provisioning logic.
- [dns_zone](dns_zone/README.md) — shared DNS zone provisioning logic.
- [flux](flux/README.md) — Flux/GitOps bootstrap integration module.
- [network](network/README.md) — network-oriented shared module group.
- [talos](talos/README.md) — reusable Talos cluster bootstrap module.
- [vault_db_secret_backend](vault_db_secret_backend/README.md) — Vault DB backend integration module.
- [vm](vm/README.md) — VM provisioning module.

## When To Edit

- Update reused behavior so it is maintained in one place across stacks.
- Update shared input/output contracts used by multiple stacks.

## Navigation

- [Terraform Index](../README.md)
