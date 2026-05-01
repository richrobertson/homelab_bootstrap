# Flux Bootstrap Module

The Flux module performs the handoff from Terraform bootstrap to GitOps-managed
cluster state.

## Responsibilities

- Read the existing GitHub repository `richrobertson/homelab_flux`.
- Run `flux_bootstrap_git` against the active cluster.
- Configure Flux to reconcile `clusters/<cluster_name>`.

## Boundary

This module installs Flux and points it at the right path. It does not own the
steady-state Kubernetes resources that Flux reconciles. Those resources belong
in `homelab_flux`.

## Inputs

- `github_repository`
- `cluster_name`

The Flux provider receives Kubernetes client configuration from the root
[providers.tf](../../providers.tf), which in turn reads it from the
[kubernetes component](../../kubernetes/README.md).

## Related Documents

- [Bootstrap architecture](../../../docs/design/bootstrap-architecture.md#flux-handoff)
- [Terraform root](../../README.md)
- [Common Terraform operations](../../../docs/runbooks/common-terraform-operations.md)
- [Component index](../../../docs/components/README.md#gitops-handoff)
