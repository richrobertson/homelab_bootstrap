# Bootstrap Architecture

`homelab_bootstrap` owns the first-stage infrastructure that has to exist before
Flux can manage Kubernetes. It builds the substrate, creates the cluster, wires
the cluster into Vault, then hands in-cluster reconciliation to
`homelab_flux`.

## Layered Handoff

```text
Vault + existing providers
  |
  v
Terraform workspace environment model
  |
  +--> production-only substrate
  |      - PostgreSQL VM
  |      - PowerDNS recursive DNS VM
  |      - PowerDNS authoritative DNS VM
  |
  +--> Proxmox SDN networking
  |      - EVPN/VXLAN zones
  |      - control-plane and data-plane VNets
  |      - per-fault-domain subnets and DNS zones
  |
  +--> Talos Kubernetes cluster
  |      - one control-plane VM per fault domain
  |      - one worker VM per fault domain
  |      - Talos machine config, secrets, bootstrap, kubeconfig
  |
  +--> Vault integration
  |      - Kubernetes auth backend
  |      - Kubernetes secrets engine
  |      - PKI policy and cert-manager roles
  |      - backup and application secret material
  |
  +--> Flux bootstrap
         - connects cluster to richrobertson/homelab_flux
         - reconciles clusters/<cluster_name>
```

## Substrate

The substrate is the small set of services that the rest of the environment
expects to already exist. In production, Terraform creates:

- `subdb1` PostgreSQL VM at `192.168.7.200`.
- PowerDNS recursive DNS exposed as `ns1.myrobertson.net`.
- PowerDNS authoritative DNS exposed as `subns.myrobertson.net`.

Staging and development do not create their own substrate. They point at the
production substrate DNS endpoints instead.

Component details:

- [terraform/substrate](../../terraform/substrate/README.md)
- [postgresql-database](../../terraform/substrate/postgresql-database)
- [powerdns-recurse](../../terraform/substrate/powerdns-recurse)
- [powerdns-auth](../../terraform/substrate/powerdns-auth)

## Networking Overlay

The networking layer creates the Proxmox SDN fabric used by Talos nodes:

- L2 VXLAN zone named `<short>l2`.
- L3 EVPN zone named `<short>l3`.
- Control-plane VNet named `<short>ctr`.
- Data-plane VNet named `<short>data`.
- One control-plane `/24` and one data-plane `/24` per fault domain.
- Forward and reverse DNS zones for the environment.

Component details:

- [terraform/networking](../../terraform/networking/README.md)
- [Environment model](environment-model.md)

## Kubernetes Overlay

The Kubernetes layer converts the SDN fabric into a Talos cluster:

- [nodes](../../terraform/kubernetes/nodes/README.md) creates one control-plane
  VM and one worker VM per fault domain.
- [talos](../../terraform/kubernetes/talos/README.md) renders and applies Talos
  machine configuration, bootstraps etcd, and exports kubeconfig/talosconfig.
- [vault_auth_backend](../../terraform/kubernetes/vault_auth_backend/README.md)
  creates the Vault Kubernetes auth backend.
- [vault_secret_backend](../../terraform/kubernetes/vault_secret_backend/README.md)
  creates the Vault Kubernetes secrets engine and Vault Secrets Operator role.
- [certs](../../terraform/kubernetes/certs/README.md) creates cert-manager Vault
  policy and auth role.

The cluster endpoint is:

```text
https://cp.<cluster_name>.myrobertson.net:6443
```

## Flux Handoff

Terraform uses [modules/flux](../../terraform/modules/flux/README.md) to run
`flux_bootstrap_git` against `richrobertson/homelab_flux`:

```text
clusters/<cluster_name>
```

After Flux is installed, steady-state Kubernetes resources should live in
`homelab_flux`: controllers, application overlays, gateways, monitoring,
dashboards, and backup workloads.

## Optional Edge Components

Optional edge components stay in bootstrap because they either sit outside the
cluster or produce secrets consumed by Flux-managed workloads:

- [Mail edge design](mail-edge.md)
- [mail_edge component](../../terraform/mail_edge/README.md)
- [Talos etcd backup runbook](../runbooks/talos-etcd-backups.md)

## Related Documents

- [Environment model](environment-model.md)
- [Component index](../components/README.md)
- [Terraform root](../../terraform/README.md)
- [Runbooks](../runbooks/README.md)
