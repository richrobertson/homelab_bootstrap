# Substrate Stack

Manages foundational substrate services required before Kubernetes workloads.

## What This Stack Manages

- Foundational backing services required before cluster-level resources are fully useful.
- Platform services that other stacks depend on (for example database and DNS substrate components).

## When To Edit

- Add or modify dependencies used by Kubernetes/bootstrap services.
- Update foundation service lifecycle, sizing, or integration behavior.

## Child Modules

- [postgresql-database](postgresql-database/README.md)
- [powerdns-auth](powerdns-auth/README.md)
- [powerdns-recurse](powerdns-recurse/README.md)

## Navigation

- [Terraform Index](../README.md)
