
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

  on_boot = true

  machine = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"

  cpu {
    cores = var.cpu_cores
    type  = "x86-64-v3"
  }

  memory {
    dedicated = tonumber(var.memory_in_gb) * 1024
  }

  cdrom {
    file_id = "none"
  }

  initialization {

    datastore_id = "p0"
    interface = "ide0"
    dns {
      domain = "myrobertson.net"
      servers = [ "192.168.1.245", "192.168.1.244" ]
    }

    dynamic "ip_config" {
      for_each = var.networks
      content {
        ipv4 {
          address = ip_config.value["ip4_address"]
          gateway = ip_config.value["ip4_gateway"]
        }
        ipv6 {
          address = "dhcp"
        }
      }
    }
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
    timeout = "90s"
  }

  disk {
    datastore_id = "p0"
    interface    = "virtio0"
    iothread     = true
    cache        = "none"
    discard      = "on"
    file_format  = "raw"

    import_from  = var.cloud_image_id
    size         = "20"
  }

}

resource "proxmox_virtual_environment_haresource" "vm" {
  resource_id  = "vm:${proxmox_virtual_environment_vm.vm.vm_id}"
  state        = "started"
  comment      = "Managed by Terraform"
}