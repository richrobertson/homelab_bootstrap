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
- Run Terraform from the directory of the stack you are working on (for example, `terraform/firewall`, `terraform/nodes`, `terraform/networking`, `terraform/kubernetes`, or `terraform/substrate`). Each stack manages its own state/backend.
- The root `terraform/` directory currently orchestrates only the `nodes` and `firewall` stacks via `terraform/main.tf`. When working here, you can still use `terraform plan/apply` and optionally `-target=module.nodes` or `-target=module.firewall` while iterating, but this will not manage `kubernetes`, `networking`, or `substrate` unless they are wired into `main.tf`.
- Confirm outputs and cross-stack assumptions before opening a PR.

## Available Stack Directories

Each directory below is an independent Terraform stack with its own state and entrypoint. Run `terraform init/plan/apply` from the stack directory you are working in. The root `terraform/main.tf` currently wires only `nodes` and `firewall`.

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
