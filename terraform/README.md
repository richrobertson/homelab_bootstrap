# Terraform Documentation Index

Manages Terraform orchestration documentation for the homelab bootstrap workflow.

## Start Here (New Developers)

If you are new to this repository, use this order:

1. Read [Repository README](../readme.md) for high-level architecture and workflow.
2. Read [substrate](substrate/README.md) to understand baseline services created before cluster bootstrap.
3. Read [networking](networking/README.md) and [nodes](nodes/README.md) for host/network layout.
4. Read [kubernetes](kubernetes/README.md) for control plane/bootstrap wiring.
5. Read [modules](modules/README.md) when modifying reusable logic used by multiple stacks.

## Typical Developer Workflow

- Make changes in the most specific stack/module possible.
- Keep reusable behavior in [modules](modules/README.md), and stack-specific wiring in stack directories.
- Use the root `terraform/` directory as the default execution entrypoint for shared state workflows (`terraform init/plan/apply`).
- The root configuration defines the shared S3 backend in `terraform/versions.tf` and currently orchestrates `nodes` and `firewall` via `terraform/main.tf`.
- Running Terraform directly in subdirectories (for example, `terraform/firewall`, `terraform/nodes`, `terraform/networking`, `terraform/kubernetes`, or `terraform/substrate`) will use local state by default unless explicit backend/state separation is configured for that directory.
- Confirm outputs and cross-stack assumptions before opening a PR.

## Available Terraform Directories

Each directory below contains Terraform configuration relevant to that area. These directories are not all independently state-isolated by default. The root `terraform/main.tf` currently wires only `nodes` and `firewall` under the root backend.

- [firewall](firewall/README.md) — firewall-specific infrastructure and policy controls.
- [kubernetes](kubernetes/README.md) — Talos/Kubernetes bootstrap and Vault/Kubernetes integration resources.
- [networking](networking/README.md) — network topology and DNS/network dependencies for cluster services.
- [nodes](nodes/README.md) — node-level resources and lifecycle integration points.
- [substrate](substrate/README.md) — foundational platform services required before full cluster enablement.

## Reusable Modules

- [modules](modules/README.md) — shared building blocks consumed by multiple stacks.

## Keeping Docs Updated

When adding or changing infrastructure behavior:

1. Update the README in the directory you changed.
2. If behavior impacts parent stack semantics, update the parent README too.
3. If a new module/stack was added, add it to the nearest index README and verify links.
4. Keep each README practical by documenting:
    - What it provisions.
    - Inputs/assumptions that are easy to miss.
    - Operational impact (what breaks if misconfigured).
    - Related modules/stacks to inspect during reviews.

Use this short template for new README files:

```md
# <Name>

One-paragraph summary of purpose and where this fits in provisioning flow.

## What This Manages

- Resource/category A
- Resource/category B

## When To Edit

- Add concrete trigger scenario 1 for this module.
- Add concrete trigger scenario 2 for this module.

## Navigation

- Parent link
- Related link
```

## Navigation

- [Repository README](../readme.md)
