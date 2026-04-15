
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
  default_packages      = concat(["qemu-guest-agent", "net-tools", "curl"], var.ansible_playbook_name == "" ? [] : ["ansible"])
  final_packages        = concat(local.default_packages, var.additional_packages)
  default_run_cmds      = ["systemctl enable qemu-guest-agent", "systemctl start qemu-guest-agent"]
  final_run_cmds        = concat(local.default_run_cmds, var.additional_runcmds, ["echo \"done\" > /tmp/cloud-config.done"])
  ansible               = var.ansible_playbook_name == "" ? "" : <<-EOF
    ansible:
      package_name: ansible-core
      install_method: distro
      pull:
        url: "https://${var.github_token}:x-oauth-basic@github.com/richrobertson/homelab_ansible.git"
        playbook_name: ${var.ansible_playbook_name}   
    EOF
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = local.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: ${var.name}
    timezone: America/Los_Angeles
    users:
      - name: root
        lock-passwd: false
        passwd: $1$SaltSalt$YhgRYajLPrYevs14poKBQ0
      - default
      - name: rich
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(var.ssh_public_key)}
        sudo: ALL=(ALL) NOPASSWD:ALL
    package_update: true
    package_upgrade: true
    packages:
    ${yamlencode(local.final_packages)}
    runcmd:
    ${yamlencode(local.final_run_cmds)} 
    EOF

    file_name = "user-data-cloud-config-${var.name}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name = var.name

  node_name = var.node_name
  tags      = var.tags

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
    file_id   = "none"
    interface = "ide0"
  }

  serial_device {

  }

  vga {
    type = var.display_type
  }

  initialization {

    datastore_id = "p0"
    interface    = "scsi0"
    dns {
      domain  = var.dns.domain
      servers = var.dns.servers
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

    user_data_file_id = var.skip_user_data_file ? null : proxmox_virtual_environment_file.user_data_cloud_config.id
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
    timeout = "100s"
  }

  disk {
    datastore_id = "p0"
    interface    = "virtio0"
    iothread     = true
    cache        = "writeback"
    discard      = "on"
    file_format  = "raw"

    import_from = var.cloud_image_id
    size        = var.disk_size
  }

  lifecycle {
    ignore_changes = [
      disk[0].import_from,
      initialization[0].user_data_file_id,
      initialization[0].ip_config,
    cpu[0].units]
  }

}

resource "proxmox_virtual_environment_haresource" "vm" {
  count       = var.ha_enabled ? 1 : 0
  resource_id = "vm:${proxmox_virtual_environment_vm.vm.vm_id}"
  state       = "started"
  comment     = "Managed by Terraform"
  lifecycle {
    ignore_changes = [comment]
  }
}