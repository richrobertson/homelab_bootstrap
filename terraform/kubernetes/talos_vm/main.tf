
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
    data = <<-EOF
    #cloud-config
    timezone: America/Los_Angeles
    ca_certs:
      remove_defaults: false
      trusted:
      - |
      -----BEGIN CERTIFICATE-----
      MIICCDCCAa+gAwIBAgIQF9zxtm7FcrlB+hsJIdZ7mzAKBggqhkjOPQQDAjBRMRMw
      EQYKCZImiZPyLGQBGRYDbmV0MRswGQYKCZImiZPyLGQBGRYLbXlyb2JlcnRzb24x
      HTAbBgNVBAMTFG15cm9iZXJ0c29uLURDMS1DQS0xMB4XDTI1MTAyMDE3MjMxNFoX
      DTQwMTAyMDE3MzMwN1owUTETMBEGCgmSJomT8ixkARkWA25ldDEbMBkGCgmSJomT
      8ixkARkWC215cm9iZXJ0c29uMR0wGwYDVQQDExRteXJvYmVydHNvbi1EQzEtQ0Et
      MTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABK+4DJe8IQJfxAzy0rPHXzB90y6j
      VH8DIkZ7MVKDiU3I4wvijS377qYF29isRM7PAIJqoBn2qrj3tq0VXf2kVqejaTBn
      MBMGCSsGAQQBgjcUAgQGHgQAQwBBMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8E
      BTADAQH/MB0GA1UdDgQWBBRDeCmhtlyh4RyCRpNsWwmHhSQIiTAQBgkrBgEEAYI3
      FQEEAwIBADAKBggqhkjOPQQDAgNHADBEAiBanuCZDMRVikhd3L9npjlcU/RfYTM9
      KBEosp9OrdExBwIgMyq4owAejBTFfxDEco8n/Si9OBQLLZ01n+vwnwLr964=
      -----END CERTIFICATE-----
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
    user_data_file_id = var.skip_user_data_file ? null : proxmox_virtual_environment_file.user_data_cloud_config.id

    datastore_id = "p0"
    interface    = "ide0"
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

}

resource "proxmox_virtual_environment_haresource" "vm" {
  count       = var.ha_enabled ? 1 : 0
  resource_id = "vm:${proxmox_virtual_environment_vm.vm.vm_id}"
  state       = "started"
  comment     = "Managed by Terraform"
}