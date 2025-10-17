

module "vm" {
  source         = "../../modules/vm"
  name           = "subns"
  cloud_image_id = var.cloud_image_id
  networks = [{
    bridge      = "vmbr1"
    firewall    = false
    vlan_tag    = 7
    ip4_address = "192.168.7.201/24"
    ip4_gateway = "192.168.7.1"
  }]
  disk_size             = "40"
  node_name             = "pve3"
  additional_packages   = ["gpg"]
  ansible_playbook_name = ""
  ssh_public_key        = var.ssh_public_key
  ha_enabled            = true
}

