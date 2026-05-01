# Networking Component

The networking module creates the Proxmox SDN overlay used by Talos control
plane and worker nodes.

## Responsibilities

- Create the environment forward DNS zone.
- Create the reverse DNS zone.
- Create an L2 VXLAN zone named `<short>l2`.
- Create an L3 EVPN zone named `<short>l3`.
- Create the control-plane VNet named `<short>ctr`.
- Create the data-plane VNet named `<short>data`.
- Create one control-plane subnet per fault domain.
- Create one data-plane subnet per fault domain.
- Apply SDN changes through Proxmox SDN applier resources.

## Addressing Model

Subnet CIDRs come from the active workspace environment:

```text
control-plane: 10.<controlplane vxlan octet>.<fault-domain-id>.0/24
data-plane:    10.<dataplane vxlan octet>.<fault-domain-id>.0/24
gateway:       .1
node address:  .2
```

## Consumers

- [kubernetes/nodes](../kubernetes/nodes/README.md) consumes the VNet bridge
  names and per-fault-domain subnets.
- [kubernetes/talos](../kubernetes/talos/README.md) ultimately uses these node
  addresses for Talos bootstrap and cluster access.

## Related Documents

- [Environment model](../../docs/design/environment-model.md#network-identity)
- [Bootstrap architecture](../../docs/design/bootstrap-architecture.md#networking-overlay)
- [Terraform root](../README.md)
- [Component index](../../docs/components/README.md#networking)
