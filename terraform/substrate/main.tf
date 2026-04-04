
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
  }
}

locals {
  cloud_image_url     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  cloud_image_url_old = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"

}

resource "proxmox_virtual_environment_download_file" "cloud_image" {
  content_type        = "import"
  datastore_id        = "cephfs"
  node_name           = "pve3"
  url                 = local.cloud_image_url
  overwrite           = false
  overwrite_unmanaged = true

  lifecycle {
    ignore_changes = [size]
  }
}

resource "proxmox_virtual_environment_download_file" "cloud_image_old" {
  content_type        = "import"
  datastore_id        = "cephfs"
  node_name           = "pve3"
  url                 = local.cloud_image_url_old
  overwrite           = false
  overwrite_unmanaged = true

  lifecycle {
    ignore_changes = [size]
  }
}

module "database" {
  source            = "./postgresql-database"
  ssh_public_key    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWOeC6oOqvDBnVpY+DU8h78cXVd2EiE6NhrCthKsm7/ rich@myrobertson.com"
  postgres_password = var.db1_password
  ip4_address       = "192.168.7.200/32"
  ip4_gateway       = "192.168.7.1"
  network_vlan_id   = 7
  network_bridge    = "vmbr1"
  node_name         = "pve3"
  hostname          = "subdb1"
  cloud_image_id    = proxmox_virtual_environment_download_file.cloud_image.id
}

module "powerdns_recurse_server" {
  source         = "./powerdns-recurse"
  depends_on     = [module.database]
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWOeC6oOqvDBnVpY+DU8h78cXVd2EiE6NhrCthKsm7/ rich@myrobertson.com"
  cloud_image_id = proxmox_virtual_environment_download_file.cloud_image_old.id
}


module "powerdns_auth_server" {
  source         = "./powerdns-auth"
  depends_on     = [module.powerdns_recurse_server]
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWOeC6oOqvDBnVpY+DU8h78cXVd2EiE6NhrCthKsm7/ rich@myrobertson.com"
  cloud_image_id = proxmox_virtual_environment_download_file.cloud_image_old.id
}