terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0-alpha.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.1"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.2"
    }
  }

  backend "s3" {
    bucket = "myrobertson-homelab-terraform"
    region = "us-west-2"
    key = "base/terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint  = "https://cl0.myrobertson.net:8006/api2/json"
  api_token = data.vault_generic_secret.proxmox_token.data["api_token"]
  insecure  = true
}

provider "talos" {}
