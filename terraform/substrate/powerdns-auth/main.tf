

module "vm" {
  source         = "../../modules/vm"
  name           = "subns"
  cloud_image_id = var.cloud_image_id
  networks = [{
    bridge      = var.network_bridge
    firewall    = false
    vlan_tag    = var.network_vlan_id
    ip4_address = var.ip4_address
    ip4_gateway = var.ip4_gateway
  }]
  disk_size           = "40"
  node_name           = "pve3"
  additional_packages = ["gpg"]
  ssh_public_key      = var.ssh_public_key
  ha_enabled          = true
}

