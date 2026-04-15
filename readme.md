# homelab_bootstrap

First-stage cluster bootstrap and orchestration before Flux management.

## Related repositories

This repository is one part of a shared homelab stack:

- [homelab_bootstrap](https://github.com/richrobertson/homelab_bootstrap) - first-stage cluster bootstrap/orchestration before Flux management.
- [homelab_ansible](https://github.com/richrobertson/homelab_ansible) - host and node configuration automation outside Kubernetes manifests.
- [homelab_flux](https://github.com/richrobertson/homelab_flux) - in-cluster GitOps state (apps, controllers, configs, and gateway resources).

## Recreating cluster
## terraform state rm module.flux.github_repository.this
terraform destroy -auto-approve  
## terraform import module.flux.github_repository.this richrobertson/homelab_flux
terraform apply -auto-approve


## Update local kubernetes context

### STAGE
terraform output -raw kubeconfig > ~/.kube/config.stage
terraform output -raw talosconfig > ~/.talos/config.stage

### PROD
terraform output -raw kubeconfig > ~/.kube/config.prod
terraform output -raw talosconfig > ~/.talos/config.prod

## Talos GPU Worker Enablement

GPU worker bootstrap is controlled by environment locals in `terraform/environment.tf`:

- `gpu_worker_fault_domains` - fault domains whose worker nodes should be configured as GPU-capable.
- `gpu_talos_installer_image` - custom Talos installer image used for GPU workers during install or upgrade.

Current GPU schematic committed for staging:

- schematic id `6698d6f136c5bb37ca8bb8482c9084305084da0a5ead1f4dcae760796f8ab3a2`
- extensions:
	- `siderolabs/nvidia-container-toolkit-production`
	- `siderolabs/nvidia-open-gpu-kernel-modules-production`

Example:

```hcl
gpu_worker_fault_domains = ["fd-0"]
gpu_talos_installer_image = "factory.talos.dev/metal-installer/<schematic-id>:v1.12.5"
```

Talos system extensions are not applied by listing extension names in machine config. Build a custom installer image with the required NVIDIA extensions, then set `gpu_talos_installer_image` to that image reference.

For existing workers booted from a pre-installed disk image, setting `gpu_talos_installer_image` makes the desired installer explicit in machine config, but the extensions only take effect when the node is reinstalled or upgraded with that image.

### Staging GPU Worker Rollout

Current staging target:

- `gpu_worker_fault_domains = ["fd-0"]`
- `gpu_talos_installer_image = "factory.talos.dev/metal-installer/6698d6f136c5bb37ca8bb8482c9084305084da0a5ead1f4dcae760796f8ab3a2:v1.11.1"`

Suggested apply sequence:

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

Expected result after bootstrap-side changes:

- worker `k8s-stg-worker-0` receives label `hardware.gpu=true`
- staging now points `fd-0` at a concrete Talos GPU installer image for future install or upgrade operations
- Kubernetes worker is ready for NVIDIA device plugin deployment from `homelab_flex`

Recommended next step for staging:

1. Build or publish a Talos Image Factory schematic that includes the required NVIDIA system extensions.
2. Set `gpu_talos_installer_image` in `terraform/environment.tf` for the `staging` workspace.
3. Re-run `terraform plan` and then upgrade or reinstall `k8s-stg-worker-0` with that installer image.

## Talos etcd backups to shared S3 bucket

Talos v1.12 machine config does not support `cluster.etcd.backup` fields, so backups are handled out-of-band via `talosctl etcd snapshot`.

### Scripted backup

Run the backup script from repository root:

```bash
bash scripts/backup_talos_etcd_to_s3.sh
```

What the script does:

1. Detects the current Terraform workspace (`staging`, `production`, etc.).
2. Exports `talosconfig` from Terraform output.
3. Uses Vault path `secret/volsync/prod/plex-config-ceph` to load S3 credentials.
4. Takes an etcd snapshot using `talosctl`.
5. Uploads snapshot to shared bucket `myrobertson-homelab-talos-etcd-backups` under prefix:
	- `stage/` for `staging`
	- `prod/` for `production` or `prod`

Required CLIs on the runner:

- `terraform`
- `talosctl`
- `vault`
- `aws`

### Jenkins integration

The Jenkins pipeline now includes stage `Talos etcd backup to S3`, which runs on `main` for non-PR builds:

```groovy
sh 'bash scripts/backup_talos_etcd_to_s3.sh'
```
