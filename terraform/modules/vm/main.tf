
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.name

  node_name = var.node_name

  cpu {
    cores = var.cpu_cores
    type  = "x86-64-v3"
  }

  memory {
    dedicated = tonumber(var.memory_in_gb) * 1024
  }

  dynamic "network_device" {
    for_each = var.networks
    content {
      bridge = network_device.value["bridge"]
      model    = "virtio"
       firewall = network_device.value["firewall"]
       vlan_id  = network_device.value["vlan_tag"]
    }
  }

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = true
    timeout = "30s"
  }

  disk {
    datastore_id = "p0"
    import_from  = var.cloud_image_id
    interface    = "virtio0"
    size         = "32"
  }

}