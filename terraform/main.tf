
locals {
  fault_domains = { for i in range(3) : "fd-${i}" => {
    id   = i
    name = "Failure Domain ${i}"
    }
  }

  # Pin Kubernetes FD index to Proxmox host mapping:
  # fd-0 -> pve3, fd-1 -> pve4, fd-2 -> pve5
  kubernetes_proxmox_ve_nodes = ["pve3", "pve4", "pve5"]

  dns_server = local.env.environment_name == "prod" ? module.substrate[0].subns_server.hostname : "subns.myrobertson.net"
  subns_server = local.env.environment_name == "prod" ? module.substrate[0].subns_server : {
    ipv4_addresses = ["192.168.7.201"]
    ipv6_addresses = []
    hostname       = "subns.myrobertson.net"
  }
  recurse_dns_server = local.env.environment_name == "prod" ? module.substrate[0].nsr_server : {
    ipv4_addresses = ["192.168.7.202"]
    ipv6_addresses = []
    hostname       = "ns1.myrobertson.net"
  }
}

module "substrate" {
  count        = local.env.environment_name == "prod" ? 1 : 0
  source       = "./substrate"
  github_token = data.vault_generic_secret.github_token.data["token"]
  db1_password = data.vault_generic_secret.substrate_db1.data["postgres_password"]
}


module "networking" {
  count                  = 1
  source                 = "./networking"
  depends_on             = [module.substrate]
  environment_name       = local.env.environment_name
  environment_short_name = local.env.environment_short_name
  fault_domains          = local.fault_domains
  dns_server             = local.dns_server
  vrf_vxlan              = local.env["vrf_vxlan"]
  dataplane_vlan_tag     = local.env["dataplane_vlan_tag"]
  controlplane_vlan_tag  = local.env["controlplane_vlan_tag"]
  vxlan_octet            = local.env["vxlan_octet"]
  nodes                  = data.proxmox_virtual_environment_nodes.available_nodes.names
  #node_ips = data.proxmox_virtual_environment_nodes.available_nodes.

}

module "kubernetes-cluster" {
  count      = 1
  source     = "./kubernetes"
  depends_on = [module.networking]

  environment_name       = local.env.environment_name
  environment_short_name = local.env.environment_short_name

  cluster_name                  = local.env.kubernetes.cluster_name
  fault_domains                 = local.fault_domains
  control_plane_network_bridge  = module.networking[0].controlplane_network.bridge_name
  control_plane_network_vlan_id = local.env["controlplane_vlan_tag"]
  control_plane_subnets_by_fd   = module.networking[0].controlplane_network.subnets_by_fd
  worker_network_bridge         = module.networking[0].dataplane_network.bridge_name
  worker_subnets_by_fd          = module.networking[0].dataplane_network.subnets_by_fd

  dns_auth_sever   = local.subns_server
  dns_server       = local.recurse_dns_server
  proxmox_ve_nodes = local.kubernetes_proxmox_ve_nodes

  kubernetes_nodes_resources = local.env.kubernetes_nodes
  vault_pki_policy_paths     = local.env.vault_pki_policy_paths
  vault_pki_role             = local.env.vault_pki_role
  enable_talos_cluster_health_check = var.enable_talos_cluster_health_check
}


module "flux" {
  count      = 1
  source     = "./modules/flux"
  depends_on = [module.kubernetes-cluster]

  github_repository = "homelab_flux"
  cluster_name      = local.env.kubernetes.cluster_name
}


module "firewall" {
  source               = "./firewall"
  fw_count             = 0
  cluster_short_name   = local.env.environment_name
  proxmox_ve_nodes     = data.proxmox_virtual_environment_nodes.available_nodes.names
  memory_in_gb         = 8
  lan_network_bridge   = "dmz"
  wan_network_bridge   = "vmbr1"
  wan_network_vlan_tag = 7
}

