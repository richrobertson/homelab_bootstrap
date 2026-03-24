
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
  }
}

locals {
  cloud_image_url = "https://factory.talos.dev/image/dc7b152cb3ea99b821fcb7340ce7168313ce393d663740b791c36f6e95fc8586/v1.11.1/nocloud-amd64.raw.xz"
}

resource "proxmox_virtual_environment_download_file" "cloud_image" {
  count               = 0
  content_type        = "import"
  datastore_id        = "cephfs"
  node_name           = "pve3"
  file_name           = "nocloud-amd64.iso"
  url                 = local.cloud_image_url
  overwrite_unmanaged = true
}

module "control_plane_vms" {
  source       = "../modules/vm"
  name         = "k8s-${var.cluster_short_name}-cp-${count.index}"
  count        = var.control_plane_count
  node_name    = var.proxmox_ve_nodes[count.index % length(var.proxmox_ve_nodes)]
  cpu_cores    = var.control_plane_cpu_cores
  memory_in_gb = var.control_plane_memory_in_gb
  networks = [
    {
      bridge      = var.network_bridge
      firewall    = false
      vlan_tag    = var.network_vlan_id
      ip4_address = "192.168.${var.network_vlan_id}.${10 + count.index}/24"
      ip4_gateway = "192.168.${var.network_vlan_id}.1"
    }
  ]
  cloud_image_id = "cephfs:import/nocloud-amd64.raw"
}


module "worker_vms" {
  source       = "../modules/vm"
  name         = "k8s-${var.cluster_short_name}-worker-${count.index}"
  count        = var.worker_count
  node_name    = var.proxmox_ve_nodes[count.index % length(var.proxmox_ve_nodes)]
  cpu_cores    = var.worker_cpu_cores
  memory_in_gb = var.worker_memory_in_gb
  networks = [
    {
      bridge      = var.network_bridge
      firewall    = false
      vlan_tag    = var.network_vlan_id
      ip4_address = "192.168.${var.network_vlan_id}.${20 + count.index}/24"
      ip4_gateway = "192.168.${var.network_vlan_id}.1"
    }
  ]
  cloud_image_id = "cephfs:import/nocloud-amd64.raw"
}

module "talos_cluster" {
  depends_on       = [module.worker_vms, module.control_plane_vms]
  source           = "../modules/talos"
  cluster_name     = var.cluster_short_name
  cluster_endpoint = "https://192.168.${var.network_vlan_id}.10:6443"
  node_data = {
    controlplanes = {
      for idx in range(var.control_plane_count) :
      "192.168.${var.network_vlan_id}.${10 + idx}" => {
        install_disk = "/dev/sda"
        hostname     = "k8s-${var.cluster_short_name}-cp-${idx}"
      }
    }
    workers = {
      for idx in range(var.worker_count) :
      "192.168.${var.network_vlan_id}.${20 + idx}" => {
        install_disk = "/dev/sda"
        hostname     = "k8s-${var.cluster_short_name}-worker-${idx}"
      }
    }
  }
}