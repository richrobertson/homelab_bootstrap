
locals {
  cluster_short_name = terraform.workspace == "default" ? "production" : "${terraform.workspace}"
}

module "nodes" {
  source = "./nodes"

  cluster_short_name         = local.cluster_short_name
  proxmox_ve_nodes           = data.proxmox_virtual_environment_nodes.available_nodes.names
  network_bridge             = "vmbr1"
  network_vlan_id            = 20
  control_plane_cpu_cores    = 4
  control_plane_memory_in_gb = 6
  control_plane_count        = 5

  worker_count        = 3
  worker_cpu_cores    = 12
  worker_memory_in_gb = 12
  dns_domain          = var.root_domain
  dns_servers         = var.default_dns_servers

}

module "firewall" {
  source               = "./firewall"
  fw_count             = 0
  cluster_short_name   = local.cluster_short_name
  proxmox_ve_nodes     = data.proxmox_virtual_environment_nodes.available_nodes.names
  memory_in_gb         = 8
  lan_network_bridge   = "dmz"
  wan_network_bridge   = "vmbr1"
  wan_network_vlan_tag = 7
  dns_domain           = var.root_domain
  dns_servers          = var.default_dns_servers
}