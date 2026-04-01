# Kubernetes Stack

Manages Kubernetes-related infrastructure, Talos bootstrapping, certificates, and Vault integrations.

## What This Stack Manages

- Talos cluster bootstrap orchestration and machine configuration wiring.
- Kubernetes-facing certificate resources and node-related integration.
- Vault authentication and secret backend resources connected to Kubernetes flows.

## When To Edit

- Update Talos bootstrap behavior, cluster endpoint assumptions, or node bootstrap sequencing.
- Update certificate or Vault integration behavior consumed by cluster components.
- Add Kubernetes stack resources that should not live in a reusable module.

## Intel iGPU Enablement

Use the Kubernetes stack inputs below when validating or rolling out Intel GPU passthrough for Talos worker nodes:

- `worker_host_pci_devices`: attaches one or more Proxmox `hostpci` devices to every worker VM.
- `worker_cloud_image_id`: lets workers boot from a distinct prepared image when Talos image testing is isolated.
- `control_plane_cloud_image_id`: keeps control planes on a separately managed image when required.
- `talos_installer_image`: pins the Talos installer image written into generated machine configuration.

Validation expectations before enabling GPU workloads in-cluster:

- Proxmox worker VM config shows the expected `hostpci` device.
- The Talos installer image includes the required Intel-related extensions.
- Worker nodes expose `/dev/dri` and the Intel GPU plugin advertises `gpu.intel.com/i915`.
- Do not rely on manual Kubernetes node labels to represent GPU availability.

Required Talos extensions for the validated Intel iGPU path:

- `siderolabs/i915`
- `siderolabs/intel-ice-firmware`
- `siderolabs/intel-ucode`
- `siderolabs/mei`

## Child Modules

- [certs](certs/README.md)
- [nodes](nodes/README.md)
- [talos](talos/README.md)
- [talos_vm](talos_vm/README.md)
- [vault_auth_backend](vault_auth_backend/README.md)
- [vault_pki_secret_backend](vault_pki_secret_backend/README.md)
- [vault_secret_backend](vault_secret_backend/README.md)

## Navigation

- [Terraform Index](../README.md)

