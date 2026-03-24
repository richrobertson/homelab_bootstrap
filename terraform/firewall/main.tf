
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
  }
}

locals {
  cloud_image_name = "netgate-installer-amd64.qcow2"
}

module "firewall_vms" {
  source       = "../modules/vm"
  name         = "k8s-${var.cluster_short_name}-fw-${count.index}"
  count        = var.fw_count
  node_name    = var.proxmox_ve_nodes[count.index % length(var.proxmox_ve_nodes)]
  cpu_cores    = var.cpu_cores
  memory_in_gb = var.memory_in_gb
  networks = [
    {
      bridge      = var.wan_network_bridge
      firewall    = true
      vlan_tag    = var.wan_network_vlan_tag
      ip4_address = "192.168.${var.wan_network_vlan_tag}.2/24"
      ip4_gateway = "192.168.${var.wan_network_vlan_tag}.1"
    },
    {
      bridge      = var.lan_network_bridge
      firewall    = true
      vlan_tag    = null
      ip4_address = "10.1.${var.wan_network_vlan_tag}.2/24"
      ip4_gateway = "10.1.0.1"
    }
  ]
  cloud_image_id = "cephfs:import/${local.cloud_image_name}"
}