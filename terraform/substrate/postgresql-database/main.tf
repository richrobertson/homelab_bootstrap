

module "vm" {
  source = "./../../modules/vm"

  name           = var.hostname
  tags           = ["substrate"]
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
    "echo \"host    all             all             0.0.0.0/0               trust\" >> /etc/postgresql/17/main/pg_hba.conf",
    "su - postgres psql -c \"ALTER USER postgres WITH PASSWORD '${var.postgres_password}';\"",
    "systemctl restart postgresql"
  ]
  ssh_public_key = var.ssh_public_key
  ha_enabled     = true
}

module "vault_database_secret_backend" {
  source             = "../../modules/vault_db_secret_backend"
  depends_on         = [module.vm]
  db_connection_name = var.hostname
  db_host_ip_address = cidrhost(var.ip4_address, 0)
}