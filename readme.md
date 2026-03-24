
# homelab_bootstrap

## Overview

`homelab_bootstrap` is the first-stage cluster bootstrap and orchestration repository for a homelab environment. It is responsible for provisioning the foundational infrastructure and Kubernetes cluster using Terraform, before handing off to GitOps management (via Flux). This repository automates the setup of VMs, networking, storage, and initial Kubernetes control plane, integrating with Vault for secrets and PowerDNS for DNS management.

### Key Features
- Automated cluster and infrastructure provisioning using Terraform
- Modular structure for substrate (VMs, storage), networking, Kubernetes, firewall, and Flux bootstrap
- Secure secrets management via Vault
- DNS automation with PowerDNS
- Designed for reproducible, idempotent cluster creation

## Repository Structure

- `terraform/` — Main Terraform configuration, with subfolders for each major component:
  - `substrate/` — Provisions VMs, storage, and base OS images
  - `networking/` — Sets up network bridges, subnets, and DNS
  - `kubernetes/` — Deploys Kubernetes nodes, control plane, and related resources
  - `firewall/` — (Optional) Provisions firewall VMs and rules
  - `modules/` — Reusable Terraform modules (VM, DNS, certificate, etc.)
- `cluster_configs/` — Talos and Kubernetes configuration files for cluster bootstrapping
- `Jenkinsfile` — CI/CD pipeline for automated provisioning

## Usage

1. **Initialize and plan Terraform:**
	```sh
	cd terraform
	terraform init
	terraform plan
	```
2. **Apply to provision infrastructure:**
	```sh
	terraform apply -auto-approve
	```
3. **Update local kubeconfig and talosconfig:**
	```sh
	terraform output -raw kubeconfig > ~/.kube/config.stage
	terraform output -raw talosconfig > ~/.talos/config.stage
	# For prod, use config.prod and talosconfig.prod
	```

4. **Destroy or re-import resources as needed:**
	```sh
	terraform destroy -auto-approve
	terraform apply -auto-approve
	```

## Related repositories

This repository is one part of a shared homelab stack:

- [homelab_bootstrap](https://github.com/richrobertson/homelab_bootstrap) - first-stage cluster bootstrap/orchestration before Flux management.
- [homelab_ansible](https://github.com/richrobertson/homelab_ansible) - host and node configuration automation outside Kubernetes manifests.
- [homelab_flux](https://github.com/richrobertson/homelab_flux) - in-cluster GitOps state (apps, controllers, configs, and gateway resources).


