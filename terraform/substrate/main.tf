# Substrate Module
#
# Provisions VMs, storage, and base OS images for the cluster. Also sets up PowerDNS and database infrastructure.

# -----------------------------
# Local Variables
# Define cloud image URLs for VM provisioning.
# -----------------------------
# -----------------------------
# Download Cloud Images
# Downloads current and previous Debian cloud images for VM provisioning.
# -----------------------------
# -----------------------------
# Database Module
# Provisions PostgreSQL database VM for the cluster.
# -----------------------------
# -----------------------------
# PowerDNS Recurse Server Module
# Provisions PowerDNS recurse server VM.
# -----------------------------
# -----------------------------
# PowerDNS Auth Server Module
# Provisions PowerDNS authoritative server VM.
# -----------------------------

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
  substrate_ip_gateway = var.substrate_ip_gateway != "" ? var.substrate_ip_gateway : var.database_ip_gateway
  dns_servers          = [split("/", var.powerdns_auth_ip_address)[0], split("/", var.powerdns_recurse_ip_address)[0]]

}

resource "proxmox_virtual_environment_download_file" "cloud_image" {
  content_type        = "import"
  datastore_id        = "cephfs"
  node_name           = "pve3"
  url                 = local.cloud_image_url
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_download_file" "cloud_image_old" {
  content_type        = "import"
  datastore_id        = "cephfs"
  node_name           = "pve3"
  url                 = local.cloud_image_url_old
  overwrite_unmanaged = true
}

module "database" {
  source          = "./postgresql-database"
  ssh_public_key  = var.ssh_public_key
  ip4_address     = var.database_ip_address
  ip4_gateway     = local.substrate_ip_gateway
  network_vlan_id = var.substrate_vlan_id
  network_bridge  = var.substrate_network_bridge
  dns_domain      = var.root_domain
  dns_servers     = local.dns_servers
  node_name       = "pve3"
  hostname        = "subdb1"
  cloud_image_id  = proxmox_virtual_environment_download_file.cloud_image.id
}

module "powerdns_recurse_server" {
  source         = "./powerdns-recurse"
  depends_on     = [module.database]
  ssh_public_key = var.ssh_public_key
  cloud_image_id = proxmox_virtual_environment_download_file.cloud_image_old.id
  ip4_address     = var.powerdns_recurse_ip_address
  ip4_gateway     = local.substrate_ip_gateway
  network_vlan_id = var.substrate_vlan_id
  network_bridge  = var.substrate_network_bridge
  dns_domain      = var.root_domain
  dns_servers     = local.dns_servers
}


module "powerdns_auth_server" {
  source         = "./powerdns-auth"
  depends_on     = [module.powerdns_recurse_server]
  ssh_public_key = var.ssh_public_key
  cloud_image_id = proxmox_virtual_environment_download_file.cloud_image_old.id
  ip4_address     = var.powerdns_auth_ip_address
  ip4_gateway     = local.substrate_ip_gateway
  network_vlan_id = var.substrate_vlan_id
  network_bridge  = var.substrate_network_bridge
  dns_domain      = var.root_domain
  dns_servers     = local.dns_servers
}