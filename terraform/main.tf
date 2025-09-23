terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
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

locals {
  cluster_short_name = terraform.workspace == "default" ? "cl0" : "${terraform.workspace}"
}

module "nodes" {
  source = "./nodes"

  cluster_short_name      = local.cluster_short_name
  proxmox_ve_nodes        = data.proxmox_virtual_environment_nodes.available_nodes.names
  network_bridge          = "dmz"
  control_plane_cpu_cores = 4
  control_plane_memory_in_gb = 6
  control_plane_count = 5

  worker_count = 3
  worker_cpu_cores = 12
  worker_memory_in_gb = 12

}

module firewall {
  source = "./firewall"
  fw_count = 1
  cluster_short_name = local.cluster_short_name
  proxmox_ve_nodes   = data.proxmox_virtual_environment_nodes.available_nodes.names
  memory_in_gb = 8
  lan_network_bridge = "dmz"
  wan_network_bridge = "vmbr1"
  wan_network_vlan_tag = 7
}