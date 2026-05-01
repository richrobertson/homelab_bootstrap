# homelab_bootstrap

`homelab_bootstrap` is the first-stage infrastructure-as-code layer for the
homelab. It creates the substrate that Kubernetes depends on, builds Talos
clusters on Proxmox, wires those clusters into Vault, and finally hands ongoing
in-cluster reconciliation to Flux.

The repository is intentionally focused on the part of the system that has to
exist before GitOps can take over. Once the cluster is reachable and Flux is
bootstrapped, application controllers, gateways, workloads, dashboards, and most
Kubernetes manifests live in `homelab_flux`.

## Repository Map

- `terraform/` - primary Terraform root for substrate, networking, Talos,
  Kubernetes, Vault integration, Flux bootstrap, backups, and the optional AWS
  mail edge.
- `docs/` - design documents, operational runbooks, and a component navigation
  index.
- `scripts/backup_talos_etcd_to_s3.sh` - operational helper that exports the
  Talos config from Terraform, snapshots etcd, and uploads the snapshot to S3.
- `Jenkinsfile` - CI/CD pipeline that initializes Terraform, plans changes,
  posts pull-request plan summaries, applies approved mainline changes, and
  runs the etcd backup job after mainline applies.

## Documentation Map

- [Docs index](docs/README.md) - start here for the full navigation map.
- [Bootstrap architecture](docs/design/bootstrap-architecture.md) - high-level
  walkthrough of substrate, overlay, Vault, Flux, and optional edge components.
- [Environment model](docs/design/environment-model.md) - workspace selection,
  fault domains, network identity, node sizing, and GPU settings.
- [Terraform root](terraform/README.md) - entry point for the executable
  Terraform layout and component links.
- [Runbooks](docs/runbooks/README.md) - operational procedures for Terraform,
  kubeconfig/talosconfig export, cluster recreation, backups, GPU workers, and
  Mailu edge operations.
- [Component index](docs/components/README.md) - crosslinked list of each
  bootstrap component and its local README.

## How This Fits With The Other Repositories

This repository is one part of a three-layer homelab stack:

- [homelab_bootstrap](https://github.com/richrobertson/homelab_bootstrap) -
  creates the pre-GitOps substrate and bootstraps Kubernetes/Flux.
- [homelab_ansible](https://github.com/richrobertson/homelab_ansible) -
  configures hosts and systems that sit outside Kubernetes manifests.
- [homelab_flux](https://github.com/richrobertson/homelab_flux) - owns the
  in-cluster GitOps state after bootstrap: controllers, platform services,
  application overlays, gateway resources, monitoring, and backup workloads.

In practice, `homelab_bootstrap` lays the road, `homelab_ansible` configures
important roadside equipment, and `homelab_flux` drives the steady-state cluster
operations.

## High-Level Architecture

The bootstrap flow is a layered handoff from Terraform-managed substrate to
Flux-managed in-cluster state. The complete walkthrough lives in
[Bootstrap Architecture](docs/design/bootstrap-architecture.md).

Optional edge components are also managed here when enabled:

- AWS Mailu edge: Elastic IP, EC2, security group, WireGuard, HAProxy, SES, and
  related DNS outputs.
- Talos etcd backup bucket and Vault-backed backup configuration.
- Mailu Vault secrets that the Flux-managed Mailu overlay consumes.

## Substrate Components

The substrate is the small set of services that the rest of the environment
expects to already exist. In the production workspace, Terraform creates:

- `subdb1` PostgreSQL VM at `192.168.7.200`.
- PowerDNS recursive DNS server exposed as `ns1.myrobertson.net`.
- PowerDNS authoritative DNS server exposed as `subns.myrobertson.net`.

Non-production workspaces do not create the substrate. They point at the
production substrate DNS endpoints instead, which keeps staging and development
clusters lightweight while still allowing them to resolve the same homelab
zones.

See [terraform/substrate](terraform/substrate/README.md) for the component
README and [Bootstrap Architecture](docs/design/bootstrap-architecture.md) for
the design context.

## Overlay Components

In this repository, "overlay" means the components layered over the raw
substrate to make a usable Kubernetes platform:

- Proxmox SDN overlays provide the control-plane and data-plane networks.
- Talos machine configuration turns Proxmox VMs into Kubernetes nodes.
- Vault auth, secret, and PKI configuration gives in-cluster controllers a way
  to retrieve secrets and issue certificates.
- Flux bootstrap installs the GitOps controller and points it at
  `homelab_flux`.
- Optional AWS Mailu edge bridges public mail traffic to the home-hosted Mailu
  deployment.

After these pieces are in place, most day-two platform work should happen in
`homelab_flux`, not here.

See the [component index](docs/components/README.md) for the local README next
to each Terraform component.

## Environment Model

Terraform workspaces select the environment definition in
`terraform/environment.tf`.

| Workspace | Environment | Short name | Cluster | Notes |
| --- | --- | --- | --- | --- |
| `production` | `prod` | `prod` | `prod` | Creates the production cluster and production-only substrate resources. |
| `staging` | `staging` | `stg` | `staging` | Creates a staging Talos cluster that reuses production substrate DNS. |
| `default` | `development` | `dev` | `development` | Development-sized cluster defaults. |

Each environment defines VLAN tags, VXLAN octets, node sizing, GPU worker
selection, Talos installer image overrides, and Vault PKI policy rules.

See [Environment Model](docs/design/environment-model.md) for the full
workspace and fault-domain walkthrough.

## Bootstrap Walkthrough

1. Terraform reads credentials and shared settings from Vault, including
   Proxmox, GitHub, Windows DNS, substrate database, Talos, and S3 credentials.
2. Production creates the substrate VMs and DNS services. Other workspaces use
   the existing substrate DNS endpoints.
3. Terraform creates Proxmox SDN EVPN/VXLAN networking for the selected
   workspace.
4. Terraform creates Talos control-plane and worker VMs across three fault
   domains mapped to `pve3`, `pve4`, and `pve5`.
5. Talos machine configuration is rendered and applied, the first control-plane
   node bootstraps etcd, and Terraform exports kubeconfig and talosconfig.
6. Vault is configured so cluster workloads can authenticate, retrieve secrets,
   and request certificates.
7. Flux is bootstrapped against `richrobertson/homelab_flux` at
   `clusters/<cluster_name>`.
8. Flux takes over the in-cluster overlay: controllers, platform services,
   application deployments, gateways, monitoring, and ongoing reconciliation.

For Terraform-specific commands, operational notes, and component details, see
[`terraform/README.md`](terraform/README.md). For operator procedures, see
[Runbooks](docs/runbooks/README.md).
