
# homelab_bootstrap

## Overview

`homelab_bootstrap` is the first-stage cluster bootstrap and orchestration repository for a homelab environment. It is responsible for provisioning the foundational infrastructure and Kubernetes cluster using Terraform, before handing off to GitOps management (via Flux). This repository automates the setup of VMs, networking, storage, and initial Kubernetes control plane, integrating with Vault for secrets and PowerDNS for DNS management.

## ⚠️ Important Security Notice

**This repository contains infrastructure-as-code templates with example/placeholder values.** Before using:

1. **Review [PUBLIC_RELEASE_GUIDE.md](PUBLIC_RELEASE_GUIDE.md)** - Complete setup and configuration instructions
2. **Review [SECURITY.md](SECURITY.md)** - Security best practices and hardening checklist
3. **Replace all default example values** with your infrastructure specifics
4. **Never commit credentials or secrets** to the repository

Infrastructure-specific values have been reviewed and many hardcoded values have been replaced with Terraform variables or example defaults. You **must** provide your actual configuration via `terraform.tfvars` before deploying.

## Key Features
- Automated cluster and infrastructure provisioning using Terraform
- Modular structure for substrate (VMs, storage), networking, Kubernetes, firewall, and Flux bootstrap
- Secure secrets management via Vault (references, not credentials stored in code)
- DNS automation with PowerDNS
- Designed for reproducible, idempotent cluster creation
- ✅ Infrastructure values reviewed and parameterized where identified
- ✅ Secret scanning integrated into CI and release hardening workflow
- ✅ Comprehensive security documentation

## Documentation

Essential reading before deployment:

- **[PUBLIC_RELEASE_GUIDE.md](PUBLIC_RELEASE_GUIDE.md)** - Configuration instructions and setup for your environment
- **[SECURITY.md](SECURITY.md)** - Security best practices, hardening checklist, and vulnerability reporting
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines for code and security standards

## Architecture

- `terraform/` — Main Terraform configuration, with subfolders for each major component:
  - `substrate/` — Provisions VMs, storage, and base OS images
  - `networking/` — Sets up network bridges, subnets, and DNS
  - `kubernetes/` — Deploys Kubernetes nodes, control plane, and related resources
  - `firewall/` — (Optional) Provisions firewall VMs and rules
  - `modules/` — Reusable Terraform modules (VM, DNS, certificate, etc.)
- `cluster_configs/` — Talos and Kubernetes configuration files for cluster bootstrapping
- `Jenkinsfile` — CI/CD pipeline for automated provisioning

## Usage

### Prerequisites

1. **Configure Your Environment**
   - Create `terraform/terraform.tfvars` with your infrastructure details
   - Review [PUBLIC_RELEASE_GUIDE.md](PUBLIC_RELEASE_GUIDE.md) for complete setup instructions
   - Ensure Vault is accessible and configured
   - Proxmox endpoint is reachable and credentials are stored in Vault

2. **Install Dependencies**
   - Terraform >= 1.10.0
   - Proxmox CLI (optional)
   - Talos CLI for cluster management

### Getting Started

1. **Environment Setup** (Required - See [PUBLIC_RELEASE_GUIDE.md](PUBLIC_RELEASE_GUIDE.md)):
	```sh
	# Copy example and update with your values
	cp terraform/terraform.tfvars.example terraform/terraform.tfvars
	# Edit terraform/terraform.tfvars with your infrastructure details
	```

2. **Initialize and plan Terraform:**
	```sh
	cd terraform
	terraform init \
	  -backend-config="bucket=your-terraform-state-bucket" \
	  -backend-config="region=us-west-2" \
	  -backend-config="key=terraform/state/homelab_bootstrap.tfstate"
	terraform plan
	```

3. **Review the plan and apply:**
	```sh
	terraform apply
	```

4. **Update local kubeconfig and talosconfig:**
	```sh
	terraform output -raw kubeconfig > ~/.kube/config.stage
	terraform output -raw talosconfig > ~/.talos/config.stage
	# For prod, use config.prod and talosconfig.prod
	```

5. **Verify cluster health:**
	```sh
	kubectl cluster-info
	talosctl health
	```

### Advanced Operations

Destroy or re-import resources as needed:
	```sh
	terraform destroy -auto-approve
	terraform import module.flux.github_repository.this your-org/homelab_flux
	terraform apply -auto-approve
	```

## Related repositories

This repository is one part of a shared homelab stack:

- [homelab_bootstrap](https://github.com/richrobertson/homelab_bootstrap) - first-stage cluster bootstrap/orchestration before Flux management.
- [homelab_ansible](https://github.com/richrobertson/homelab_ansible) - host and node configuration automation outside Kubernetes manifests.
- [homelab_flux](https://github.com/richrobertson/homelab_flux) - in-cluster GitOps state (apps, controllers, configs, and gateway resources).

## Security (Code scanning / SAST)

This repository runs both [Semgrep](https://semgrep.dev/) and [GitHub CodeQL](https://docs.github.com/code-security/code-scanning) via GitHub Actions on push/pull requests to `main`/`master`, with scheduled scans as well.

When GitHub code scanning is enabled for the repository, CodeQL uploads SARIF results to **GitHub Security**:

> **Repository → Security → Code scanning alerts**

Workflow files:
- Semgrep: [.github/workflows/sast-semgrep.yml](.github/workflows/sast-semgrep.yml)
- CodeQL: [.github/workflows/codeql.yml](.github/workflows/codeql.yml)

> **Note:** This workflow currently keeps CodeQL upload disabled until repository code scanning is enabled. Semgrep continues to run on every PR, and CodeQL analysis still executes in CI for workflow validation.


