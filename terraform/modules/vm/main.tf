
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
  }
}

locals {
  snippets_datastore_id = "cephfs"
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = local.snippets_datastore_id
  node_name    = var.node_name
  overwrite    = true

  source_raw {
    data = <<EOF
#cloud-config
%{if trimspace(var.ssh_public_key) != ""~}
ssh_authorized_keys:
  - ${var.ssh_public_key}
%{endif~}
%{if length(var.additional_packages) > 0~}
packages:
%{for pkg in var.additional_packages~}
  - ${pkg}
%{endfor~}
%{endif~}
%{if length(var.additional_runcmds) > 0~}
runcmd:
%{for cmd in var.additional_runcmds~}
  - ${jsonencode(cmd)}
%{endfor~}
%{endif~}
EOF

    file_name = "user-data-cloud-config-${var.name}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name = var.name

  node_name = var.node_name

  on_boot = true

  machine       = "q35"
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
    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id

    datastore_id = "p0"
    interface    = "ide0"
    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
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
      bridge   = network_device.value["bridge"]
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
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"

    import_from = var.cloud_image_id
    size        = var.disk_size
  }

}

resource "proxmox_virtual_environment_haresource" "vm" {
  count       = var.ha_enabled ? 1 : 0
  resource_id = "vm:${proxmox_virtual_environment_vm.vm.vm_id}"
  state       = "started"
  comment     = "Managed by Terraform"
}