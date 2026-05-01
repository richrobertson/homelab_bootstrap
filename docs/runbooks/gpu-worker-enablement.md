# GPU Worker Enablement

GPU worker bootstrap is controlled by environment locals in
[terraform/environment.tf](../../terraform/environment.tf).

## Configuration

- `gpu_worker_fault_domains` - fault domains whose worker nodes should be
  configured as GPU-capable.
- `gpu_talos_installer_image` - custom Talos installer image used for GPU
  workers during install or upgrade.

Example:

```hcl
gpu_worker_fault_domains = ["fd-0"]
gpu_talos_installer_image = "factory.talos.dev/metal-installer/<schematic-id>:v1.12.6"
```

Talos system extensions are not applied by listing extension names in machine
config. Build a custom installer image with the required extensions, then set
`gpu_talos_installer_image` to that image reference.

For existing workers booted from a pre-installed disk image, setting
`gpu_talos_installer_image` makes the desired installer explicit in machine
config, but the extensions only take effect when the node is reinstalled or
upgraded with that image.

Current production uses a custom Talos installer image for all three worker
fault domains. Staging currently has GPU workers disabled:

```hcl
gpu_worker_fault_domains  = []
gpu_talos_installer_image = null
```

## Staging Rollout Sequence

```bash
cd terraform
terraform workspace select staging
terraform plan -no-color -out staging-gpu-worker.plan
terraform apply staging-gpu-worker.plan
terraform output -raw kubeconfig > ~/.kube/config.stage
terraform output -raw talosconfig > ~/.talos/config.stage
kubectl --kubeconfig ~/.kube/config.stage get nodes --show-labels
kubectl --kubeconfig ~/.kube/config.stage describe node k8s-stg-worker-0 | grep -A3 -E 'Labels:|Taints:|Allocatable'
```

Expected bootstrap-side result:

- The selected worker receives the Proxmox GPU passthrough mapping.
- The worker Talos config points at the custom GPU installer image.
- The node is ready for NVIDIA or Intel device-plugin deployment from
  `homelab_flux`, depending on the selected hardware and Flux overlay.

## Related Documents

- [Environment model](../design/environment-model.md)
- [kubernetes/nodes component](../../terraform/kubernetes/nodes/README.md)
- [kubernetes/talos component](../../terraform/kubernetes/talos/README.md)
