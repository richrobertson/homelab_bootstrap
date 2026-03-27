terraform {
  required_version = ">= 1.10.0"

  required_providers {
    dns = {
      source  = "hashicorp/dns"
      version = ">=3.4.3"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.2"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.1"
    }
    microsoftadcs = {
      source  = "flipyap/microsoft-adcs"
      version = "= 0.1.6"
    }
    powerdns = {
      source  = "pan-net/powerdns"
      version = ">=1.5.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0-alpha.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">=5.3.0"
    }
  }

  backend "s3" {
    # Backend settings are intentionally not hardcoded for public use.
    # Configure with -backend-config flags or environment-specific backend config files.
    # Example:
    # terraform init \
    #   -backend-config="bucket=my-homelab-terraform-state" \
    #   -backend-config="region=us-west-2" \
    #   -backend-config="key=base/terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = data.vault_kv_secret_v2.proxmox_token.data["api_token"]
  insecure  = var.proxmox_insecure
}

provider "talos" {}