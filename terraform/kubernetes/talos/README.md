# Talos Component

The Talos component renders machine configuration, applies it to the Proxmox
VMs, bootstraps etcd, checks cluster health, and exports Kubernetes/Talos client
configuration.

## Responsibilities

- Generate Talos machine secrets.
- Render control-plane and worker machine configs.
- Apply shared patches for DNS, time, root CA trust, kernel args, and server
  certificate rotation.
- Apply control-plane taints and bootstrap manifests.
- Set worker install disk, hostname, and optional custom installer image.
- Bootstrap etcd on the first control-plane node.
- Run cluster health checks outside staging.
- Export `kubeconfig` and `talosconfig`.
- Patch CoreDNS placement during staging bootstrap.

## Important Paths

- [main.tf](main.tf) - Talos config, apply, bootstrap, health, and kubeconfig.
- [files](files) - static Talos config patches and bootstrap manifests.
- [templates](templates) - per-node Talos patch templates.
- [secrets](secrets) - generated Talos secrets and CA material.

## Consumers

- The root [outputs.tf](../../outputs.tf) exposes `kubeconfig` and
  `talosconfig`.
- [vault_auth_backend](../vault_auth_backend/README.md) uses the Kubernetes API
  endpoint and CA.
- [modules/flux](../../modules/flux/README.md) uses the Kubernetes client
  configuration through the Flux provider.

## Related Documents

- [kubernetes parent](../README.md)
- [Common Terraform operations](../../../docs/runbooks/common-terraform-operations.md)
- [Talos etcd backups](../../../docs/runbooks/talos-etcd-backups.md)
- [GPU worker enablement](../../../docs/runbooks/gpu-worker-enablement.md)
- [Component index](../../../docs/components/README.md#kubernetes)
