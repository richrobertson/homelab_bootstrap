

module "vm" {
  source = "./../../modules/vm"

  name           = var.hostname
  cloud_image_id = var.cloud_image_id
  networks = [{
    bridge      = var.network_bridge
    firewall    = false
    vlan_tag    = var.network_vlan_id
    ip4_address = var.ip4_address
    ip4_gateway = var.ip4_gateway
  }]
  disk_size           = "40"
  node_name           = var.node_name
  additional_packages = ["postgresql"]
  additional_runcmds = [
    "sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/\" /etc/postgresql/17/main/postgresql.conf",
    "echo \"host    all             all             ${cidrsubnet(var.ip4_address, 0, 0)}               scram-sha-256\" >> /etc/postgresql/17/main/pg_hba.conf",
    "systemctl restart postgresql"
  ]
  dns_domain     = var.dns_domain
  dns_servers    = var.dns_servers
  ssh_public_key = var.ssh_public_key
  ha_enabled     = true
}