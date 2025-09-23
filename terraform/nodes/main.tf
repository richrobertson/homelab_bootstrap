
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
  }
}

locals {
  cloud_image_url = "https://factory.talos.dev/image/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b/v1.11.1/metal-amd64.qcow2"
}

resource "proxmox_virtual_environment_download_file" "cloud_image" {
  content_type = "import"
  datastore_id = "cephfs"
  node_name    = "pve3"
  url          = local.cloud_image_url
  file_name    = "talos-cloud-image-${var.cluster_short_name}.qcow2"
  overwrite_unmanaged = true
}

module "control_plane_vms" {
  source = "../modules/vm"
  name = "k8s-${var.cluster_short_name}-cp-${count.index}"
  count = var.control_plane_count
  node_name = var.proxmox_ve_nodes[count.index % length(var.proxmox_ve_nodes)]
  cpu_cores   = var.control_plane_cpu_cores
  memory_in_gb = var.control_plane_memory_in_gb
  networks = [
    {
      bridge = var.network_bridge
      firewall = false
      vlan_tag = var.network_vlan_id
    }
  ]
  cloud_image_id = proxmox_virtual_environment_download_file.cloud_image.id
}


module "worker_vms" {
  source = "../modules/vm"
  name = "k8s-${var.cluster_short_name}-wrk-${count.index}"
  count = var.worker_count
  node_name = var.proxmox_ve_nodes[count.index % length(var.proxmox_ve_nodes)]
  cpu_cores   = var.worker_cpu_cores
  memory_in_gb = var.worker_memory_in_gb
  networks = [
    {
      bridge = var.network_bridge
      firewall = false
      vlan_tag = var.network_vlan_id
    }
  ]
  cloud_image_id = proxmox_virtual_environment_download_file.cloud_image.id
}