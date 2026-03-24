
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
  }
}

locals {
  cloud_image_url = "https://factory.talos.dev/image/dc7b152cb3ea99b821fcb7340ce7168313ce393d663740b791c36f6e95fc8586/v1.11.1/nocloud-amd64.raw.xz"
}

resource "proxmox_virtual_environment_download_file" "cloud_image" {
  count               = 0
  content_type        = "import"
  datastore_id        = "cephfs"
  node_name           = "pve3"
  file_name           = "nocloud-amd64.iso"
  url                 = local.cloud_image_url
  overwrite_unmanaged = true
}

module "control_plane_subnet_domains" {
  for_each  = var.fault_domains
  source    = "../../modules/dns_zone"
  zone_name = "cp.${each.key}.${var.dns.domain}"
}

module "control_plane_vms" {
  depends_on          = [module.control_plane_subnet_domains]
  source              = "../talos_vm"
  for_each            = var.fault_domains
  skip_user_data_file = false
  name                = "k8s-${var.cluster_short_name}-cp-${each.value.id}"
  node_name           = var.proxmox_ve_nodes[each.value.id]
  cpu_cores           = var.control_plane_cpu_cores
  memory_in_gb        = var.control_plane_memory_in_gb
  networks = [
    {
      bridge      = var.control_plane_network_bridge
      firewall    = false
      vlan_tag    = var.control_plane_network_vlan_id
      ip4_address = "${cidrhost(var.control_plane_subnets_by_fd[each.key].cidr, 2)}/24"
      ip4_gateway = cidrhost(var.control_plane_subnets_by_fd[each.key].cidr, 1)
    }
  ]
  display_type   = "std"
  cloud_image_id = "cephfs:import/nocloud-amd64-2.raw"
  disk_size      = "33G"
  dns = {
    domain  = "cp.${each.key}.${var.dns.domain}"
    servers = var.dns.servers.ipv4_addresses
  }
  ha_enabled = false
}

module "control_plane_subdomain_https" {
  depends_on = [module.control_plane_vms]
  source     = "../../modules/dns_record"
  record = {
    zone_name = var.dns.domain
    name      = "cp"
    type      = "https"
    records   = ["1 . ipv4hint=auto"]
  }
}

module "control_plane_subdomain_ipv4" {
  depends_on = [module.control_plane_vms]
  source     = "../../modules/dns_record"
  record = {
    zone_name = var.dns.domain
    name      = "cp"
    type      = "a"
    records   = [for ipv4 in flatten([for cp_vm in module.control_plane_vms : cp_vm.ipv4_addresses]) : ipv4 if !startswith(ipv4, "10.244")]
  }
}

/* module "control_plane_subdomain_ipv6" {
  depends_on = [ module.control_plane_vms ]
  source = "../../modules/dns_record"
  record = {
    zone_name = var.dns.domain
    name = "cp"
    type = "AAAA"
    records = flatten([for cp_vm in module.control_plane_vms: cp_vm.ipv6_addresses])
  }
} */

module "control_plane_host_records" {
  depends_on = [module.control_plane_subnet_domains]
  for_each   = var.fault_domains
  source     = "../../modules/dns_record"
  record = {
    zone_name = "cp.${each.key}.${var.dns.domain}"
    name      = "k8s-${var.cluster_short_name}-cp-${each.value.id}"
    type      = "a"
    records   = [for ipv4_addresses in module.control_plane_vms[each.key].ipv4_addresses : ipv4_addresses if !startswith(ipv4_addresses, "10.244")]
  }
}



module "data_plane_subnet_domains" {
  for_each  = var.fault_domains
  source    = "../../modules/dns_zone"
  zone_name = "dp.${each.key}.${var.dns.domain}"
}

module "worker_vms" {
  depends_on = [ module.data_plane_subnet_domains, module.control_plane_vms ]
  source   = "../talos_vm"
  for_each = var.fault_domains

  name         = "k8s-${var.cluster_short_name}-worker-${each.value.id}"
  node_name    = var.proxmox_ve_nodes[each.value.id]
  cpu_cores    = var.worker_cpu_cores
  memory_in_gb = var.worker_memory_in_gb
  networks = [
    {
      bridge      = var.worker_network_bridge
      firewall    = false
      vlan_tag    = null
      ip4_address = "${cidrhost(var.worker_subnets_by_fd[each.key].cidr, 2)}/24"
      ip4_gateway = cidrhost(var.worker_subnets_by_fd[each.key].cidr, 1)
    }
  ]
  display_type   = "std"
  cloud_image_id = "cephfs:import/nocloud-amd64-2.raw"
  disk_size      = "50G"
  dns = {
    domain  = "dp.${each.key}.${var.dns.domain}"
    servers = var.dns.servers.ipv4_addresses
  }
  ha_enabled = false
}

module "data_plane_host_records" {
  depends_on = [module.data_plane_subnet_domains]
  for_each   = var.fault_domains
  source     = "../../modules/dns_record"
  record = {
    zone_name = "dp.${each.key}.${var.dns.domain}"
    name      = "k8s-${var.cluster_short_name}-dp-${each.value.id}"
    type      = "a"
    records   = [for ipv4_addresses in module.worker_vms[each.key].ipv4_addresses : ipv4_addresses if !startswith(ipv4_addresses, "10.244")]
  }
}

/* module "grafana_host_record" {
  depends_on = [ module.data_plane_subnet_domains ]
  source = "../../modules/dns_record"
  record = {
    zone_name = var.dns.domain
    name =  "grafana"
    type = "a"
    records = ["192.168.7.151"]
  }
} */

# module "data_plane_host_ipv6_records" {
#   depends_on = [ module.data_plane_subnet_domains ]
#   for_each = var.fault_domains
#   source = "../../modules/dns_record"
#   record = {
#     zone_name = "dp.${each.key}.${var.dns.domain}"
#     name =  "k8s-${var.cluster_short_name}-dp-${each.value.id}"
#     type = "AAAA"
#     records = [for ipv6_addresses in module.worker_vms[each.key].ipv6_addresses: ipv6_addresses]
#   }
# }


