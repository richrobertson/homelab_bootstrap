# Documentation Index

This directory separates design material from operational procedures and points
back to component READMEs in the Terraform tree.

## Design Documents

- [Bootstrap architecture](design/bootstrap-architecture.md) - end-to-end
  walkthrough of substrate, overlay, Vault, Flux, and optional edge components.
- [Environment model](design/environment-model.md) - Terraform workspaces,
  environment names, fault domains, network identity, node sizing, and GPU
  settings.
- [Mail edge design](design/mail-edge.md) - AWS, WireGuard, HAProxy, SES, DNS,
  and Mailu Vault secret design.

## Operational Runbooks

- [Runbook index](runbooks/README.md)
- [Common Terraform operations](runbooks/common-terraform-operations.md)
- [Talos etcd backups](runbooks/talos-etcd-backups.md)
- [GPU worker enablement](runbooks/gpu-worker-enablement.md)
- [Mail edge operations](runbooks/mail-edge-operations.md)

## Component Navigation

- [Component index](components/README.md) - dependency-oriented map of the
  Terraform components.
- [Terraform root](../terraform/README.md) - root module entry point.
- [Root repository README](../readme.md) - project-level overview.

## Reading Paths

New reader:

1. [Root repository README](../readme.md)
2. [Bootstrap architecture](design/bootstrap-architecture.md)
3. [Environment model](design/environment-model.md)
4. [Component index](components/README.md)
5. [Common Terraform operations](runbooks/common-terraform-operations.md)

Operator:

1. [Terraform root](../terraform/README.md)
2. [Runbook index](runbooks/README.md)
3. [Talos etcd backups](runbooks/talos-etcd-backups.md)
4. [GPU worker enablement](runbooks/gpu-worker-enablement.md)

Mail edge work:

1. [Mail edge design](design/mail-edge.md)
2. [mail_edge component README](../terraform/mail_edge/README.md)
3. [Mail edge operations](runbooks/mail-edge-operations.md)
