# Kubernetes Nodes Component

The nodes component creates the Proxmox VMs that Talos turns into Kubernetes
nodes.

## Responsibilities

- Download or reference the Talos Image Factory NoCloud image.
- Create one control-plane VM per fault domain.
- Create one worker VM per fault domain.
- Create control-plane and data-plane DNS subzones.
- Create host `A` records for control-plane and worker nodes.
- Apply GPU `hostpci` mapping to selected worker fault domains.

## Naming

- Control-plane VMs: `k8s-<short>-cp-<id>`
- Worker VMs: `k8s-<short>-worker-<id>`
- Control-plane DNS zones: `cp.<fd>.<environment>.myrobertson.net`
- Data-plane DNS zones: `dp.<fd>.<environment>.myrobertson.net`

## GPU Workers

Workers in `gpu_worker_fault_domains` receive the configured Proxmox `hostpci`
mapping. The matching Talos installer image is written by
[kubernetes/talos](../talos/README.md).

## Related Documents

- [kubernetes parent](../README.md)
- [networking component](../../networking/README.md)
- [Environment model](../../../docs/design/environment-model.md#gpu-workers)
- [GPU worker enablement](../../../docs/runbooks/gpu-worker-enablement.md)
- [Component index](../../../docs/components/README.md#kubernetes)
