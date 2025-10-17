
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
        MIIDkTCCAnmgAwIBAgIQbF/+UropyJJDIybKYxHWGjANBgkqhkiG9w0BAQsFADBP
        MRMwEQYKCZImiZPyLGQBGRYDbmV0MRswGQYKCZImiZPyLGQBGRYLbXlyb2JlcnRz
        b24xGzAZBgNVBAMTEm15cm9iZXJ0c29uLURDMS1DQTAeFw0yNTEwMDgxNjA4NDNa
        Fw0zMDEwMDgxNjE4NDJaME8xEzARBgoJkiaJk/IsZAEZFgNuZXQxGzAZBgoJkiaJ
        k/IsZAEZFgtteXJvYmVydHNvbjEbMBkGA1UEAxMSbXlyb2JlcnRzb24tREMxLUNB
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuywOllpF0hUOy/wtCPZL
        s8AMujvYEzaKoDoVYHyTH4KozAVAnuQwoBFvSs5Vzhh3RXyde4vV8kYP3dRLU3H8
        o3MB6g0CkB/229r6QBjkeHUdqC9iViRID6Ayyiw8Y0/WtI4HoF+NYEsSVxcIdg3d
        Smq1iC/vNhCnnrhydlmHya4B823/5SEvVAAzHmFi5KlebtQinN3tbEpnf3T2KdSq
        zHk8JJtCiloWMVI/2MLYr6PvBnA72DooeZ5ZV2x5185R/Vsd4q5D8HUPXjDnVG+7
        BUEh9A9bblJqmAN6CdC0JyY6G4+jVv0Ex8NfA/9OsAqJA/QPfxEiQ7NFIMONAVeI
        NQIDAQABo2kwZzATBgkrBgEEAYI3FAIEBh4EAEMAQTAOBgNVHQ8BAf8EBAMCAYYw
        DwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUsZJHlspjMaonYzRUZ3pH9q51guMw
        EAYJKwYBBAGCNxUBBAMCAQAwDQYJKoZIhvcNAQELBQADggEBAB0OQSSsBgtYcfLJ
        l1HS2a2Wplrvms09Cyqc0dKZDDjPdC4VM0UyektRui5/qo5nERASfs3nz491ex1u
        ZFzpw3Kf/aUgnaQIZzKKQrU4alEFGTJhJQv4QSE5wiO1asHlFa/Z8Nw4ViHm1Rlg
        lTtlJRY0XW2vbSOpJCiOAU/ZS6MIF3kqJlTitgsWNT8rO+p6Oy6PX22jwh1Foa8i
        x03+h2L3BR4ZDHMTIauMsoyyWhE0FSK6icvMyQoasZ+Oi0NHhLL7JYsgECxl8af+
        EXtMCwioMHky8ZQXMcfHdSKMoH6HiyW4aAkv6z7VgRzRH85xUpo0VbHo+pQ1K190
        S30eyiw=
        -----END CERTIFICATE----
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