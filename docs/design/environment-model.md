# Environment Model

The active Terraform workspace selects `local.env` from
[terraform/environment.tf](../../terraform/environment.tf). That workspace model
drives cluster naming, SDN identity, node sizing, GPU worker selection, and
Vault PKI policy.

## Workspaces

| Workspace | Environment name | Short name | Cluster name | Primary use |
| --- | --- | --- | --- | --- |
| `production` | `prod` | `prod` | `prod` | Production substrate and production Kubernetes. |
| `staging` | `staging` | `stg` | `staging` | Staging Kubernetes, reusing production substrate DNS. |
| `default` | `development` | `dev` | `development` | Development defaults. |

## Fault Domains

Fault domains are always modeled as `fd-0`, `fd-1`, and `fd-2`.

The Kubernetes Proxmox host mapping is pinned in
[terraform/main.tf](../../terraform/main.tf):

| Fault domain | Proxmox host |
| --- | --- |
| `fd-0` | `pve3` |
| `fd-1` | `pve4` |
| `fd-2` | `pve5` |

Each fault domain receives one control-plane VM and one worker VM. See
[kubernetes/nodes](../../terraform/kubernetes/nodes/README.md).

## Network Identity

Each environment defines:

- `vrf_vxlan`
- `controlplane_vlan_tag`
- `dataplane_vlan_tag`
- `vxlan_octet.controlplane`
- `vxlan_octet.dataplane`
- `vxlan_octet.metallb`

Subnet layout:

```text
control-plane: 10.<controlplane vxlan octet>.<fault-domain-id>.0/24
data-plane:    10.<dataplane vxlan octet>.<fault-domain-id>.0/24
gateway:       .1
node address:  .2
```

The implementation lives in [terraform/networking](../../terraform/networking/README.md).

## Node Sizing

`kubernetes_nodes.controlplane` and `kubernetes_nodes.dataplane` define CPU and
memory for control-plane and worker VMs. These values are passed into
[terraform/kubernetes](../../terraform/kubernetes/README.md), then into
[terraform/kubernetes/nodes](../../terraform/kubernetes/nodes/README.md).

## GPU Workers

GPU worker behavior is controlled by:

- `gpu_worker_fault_domains`
- `gpu_talos_installer_image`

Selected worker fault domains receive the configured Proxmox `hostpci` mapping
and the optional custom Talos installer image. Operational steps live in the
[GPU worker enablement runbook](../runbooks/gpu-worker-enablement.md).

## Vault PKI Policy

Each environment defines:

- `vault_pki_policy_paths`
- `vault_pki_role`

These values are consumed by [kubernetes/certs](../../terraform/kubernetes/certs/README.md)
and [kubernetes/vault_pki_secret_backend](../../terraform/kubernetes/vault_pki_secret_backend/README.md).

## Related Documents

- [Bootstrap architecture](bootstrap-architecture.md)
- [Terraform root](../../terraform/README.md)
- [Component index](../components/README.md)
