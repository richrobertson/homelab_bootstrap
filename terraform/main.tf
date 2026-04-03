
locals {
  cluster_short_name = terraform.workspace == "default" ? "production" : "${terraform.workspace}"
  environment_short_name = terraform.workspace == "default" ? "prd" : (terraform.workspace == "staging" ? "stg" : substr(terraform.workspace, 0, min(3, length(terraform.workspace))))
  github_repository_name = length(split("/", var.github_repository)) > 1 ? split("/", var.github_repository)[1] : var.github_repository

  fault_domains = {
    "fd-0" = {
      id   = 0
      name = "fd-0"
    }
    "fd-1" = {
      id   = 1
      name = "fd-1"
    }
    "fd-2" = {
      id   = 2
      name = "fd-2"
    }
  }
}

moved {
  from = module.kubernetes-cluster.module.vault_pki_secret_backend.microsoftadcs_certificate.intermediate_ca_cert
  to   = module.kubernetes-cluster[0].module.vault_pki_secret_backend.microsoftadcs_certificate.intermediate_ca_cert
}

moved {
  from = module.kubernetes-cluster.module.talos_cluster.module.secrets.module.etcd.microsoftadcs_certificate.this
  to   = module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.etcd.microsoftadcs_certificate.this
}

moved {
  from = module.kubernetes-cluster.module.talos_cluster.module.secrets.module.k8s.microsoftadcs_certificate.this
  to   = module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.k8s.microsoftadcs_certificate.this
}

moved {
  from = module.kubernetes-cluster.module.talos_cluster.module.secrets.module.k8s_aggregator.microsoftadcs_certificate.this
  to   = module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.k8s_aggregator.microsoftadcs_certificate.this
}

moved {
  from = module.kubernetes-cluster.module.talos_cluster.module.secrets.module.os.microsoftadcs_certificate.this
  to   = module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.os.microsoftadcs_certificate.this
}

module "networking" {
  source = "./networking"
  count  = 1

  nodes                  = toset(data.proxmox_virtual_environment_nodes.available_nodes.names)
  fault_domains          = local.fault_domains
  environment_name       = local.cluster_short_name
  environment_short_name = local.environment_short_name
  root_domain            = var.root_domain
  dns_server             = var.dns_update_server
  vrf_vxlan              = 4000
  dataplane_vlan_tag     = 2000
  controlplane_vlan_tag  = 1000
  vxlan_octet = {
    controlplane = 20
    dataplane    = 21
  }
}

module "kubernetes-cluster" {
  source = "./kubernetes"
  count  = 1

  environment_name           = local.cluster_short_name
  environment_short_name     = local.environment_short_name
  root_domain                = var.root_domain
  organization               = "MyRobertson.net"
  cluster_name               = local.cluster_short_name
  
  authoritative_nameserver   = var.dns_update_server
  proxmox_ve_nodes           = data.proxmox_virtual_environment_nodes.available_nodes.names
  dns_auth_server            = {
    ipv4_addresses = var.default_dns_servers
    ipv6_addresses = []
  }
  
  fault_domains = local.fault_domains

  # Network configuration
  control_plane_network_bridge  = module.networking[0].controlplane_network.bridge_name
  control_plane_network_vlan_id = module.networking[0].controlplane_network.vlan_id
  control_plane_subnets_by_fd   = module.networking[0].controlplane_network.subnets_by_fd

  worker_network_bridge   = module.networking[0].dataplane_network.bridge_name
  worker_network_vlan_id  = module.networking[0].dataplane_network.vlan_id
  worker_subnets_by_fd    = module.networking[0].dataplane_network.subnets_by_fd
  
  # Cloud image configuration
  control_plane_cloud_image_id = "cephfs:import/nocloud-amd64.raw"
  worker_cloud_image_id        = "cephfs:import/nocloud-amd64.raw"
  worker_host_pci_devices = [
    {
      device = "hostpci0"
      id     = "0000:00:02.0"
      pcie   = true
    }
  ]
  
  # Resource configuration
  kubernetes_nodes_resources = {
    controlplane = {
      cpu_cores    = 8
      memory_in_gb = 8
    }
    dataplane = {
      cpu_cores    = 12
      memory_in_gb = 20
    }
  }
  
  dns_server = {
    ipv4_addresses = var.default_dns_servers
    ipv6_addresses = []
  }
  
  talos_installer_image = "ghcr.io/siderolabs/installer:latest"
}

module "flux" {
  source = "./modules/flux"
  count  = var.enable_flux ? 1 : 0

  github_repository = local.github_repository_name
  cluster_name      = local.cluster_short_name
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