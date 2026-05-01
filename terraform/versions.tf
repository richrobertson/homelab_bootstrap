terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
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
    dns = {
      source  = "hashicorp/dns"
      version = ">=3.4.3"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">=5.3.0"
    }
    powerdns = {
      source  = "pan-net/powerdns"
      version = ">=1.5.0"
    }
    microsoftadcs = {
      source = "registry.terraform.io/flipyap/microsoft-adcs"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }

  backend "s3" {
    bucket = "myrobertson-homelab-terraform"
    region = "us-west-2"
    key    = "base/terraform.tfstate"
  }
}
