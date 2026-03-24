# Networking Module
#
# Sets up network bridges, subnets, SDN zones, and DNS for the cluster.

# -----------------------------
# Data Sources
# Fetches DNS A records for peer nodes.
# -----------------------------
# -----------------------------
# Local Variables
# Define DNS zones, controller, and IPAM settings.
# -----------------------------
# -----------------------------
# DNS Zone Modules
# Provisions forward and reverse DNS zones.
# -----------------------------
# -----------------------------
# SDN Zone Resources
# Provisions L2 overlay and L3 network SDN zones.
# -----------------------------
# -----------------------------
# VNet and Subnet Resources
# Provisions virtual networks and subnets for control plane and dataplane.
# -----------------------------

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.83.2"
    }
    dns = {
      source  = "hashicorp/dns"
      version = ">=3.4.3"
    }
  }
}

data "dns_a_record_set" "peers" {
  for_each = toset(var.nodes)
  host     = each.key
}


locals {
  dns_zone         = "${var.environment_name}.myrobertson.net"
  evpn_controller  = "pve"
  ipam             = "netbox"
  reverse_dns_zone = "10.in-addr.arpa"
}

module "dns_zone" {
  source    = "../modules/dns_zone"
  zone_name = local.dns_zone
}

module "reverse_dns_zone" {
  source    = "../modules/dns_zone"
  zone_name = local.reverse_dns_zone
}

resource "proxmox_virtual_environment_sdn_zone_vxlan" "l2_overlay" {
  id    = "${var.environment_short_name}l2"
  nodes = var.nodes
  peers = flatten([for peer in data.dns_a_record_set.peers : peer.addrs[0]])
  mtu   = 1450

  # Optional attributes
  dns         = var.environment_name
  dns_zone    = local.dns_zone
  ipam        = local.ipam
  reverse_dns = var.environment_name
}

resource "proxmox_virtual_environment_sdn_zone_evpn" "l3_network" {
  id         = "${var.environment_short_name}l3"
  nodes      = var.nodes
  controller = local.evpn_controller
  vrf_vxlan  = var.vrf_vxlan

  # Optional attributes
  advertise_subnets          = true
  disable_arp_nd_suppression = false
  exit_nodes                 = tolist(var.nodes)
  exit_nodes_local_routing   = false
  #primary_exit_node          = tolist(var.nodes)[0]
  rt_import = "65000:65000"
  mtu       = 1450

  # Generic optional attributes
  dns         = var.environment_name
  dns_zone    = local.dns_zone
  ipam        = local.ipam
  reverse_dns = var.environment_name
}

resource "proxmox_virtual_environment_sdn_vnet" "controlplane" {
  id   = "${var.environment_short_name}ctr"
  zone = proxmox_virtual_environment_sdn_zone_evpn.l3_network.id
  tag  = var.controlplane_vlan_tag
}

resource "proxmox_virtual_environment_sdn_subnet" "controlplane_subnets" {
  for_each        = var.fault_domains
  cidr            = "10.${var.vxlan_octet["controlplane"]}.${each.value.id}.0/24"
  vnet            = proxmox_virtual_environment_sdn_vnet.controlplane.id
  gateway         = "10.${var.vxlan_octet["controlplane"]}.${each.value.id}.1"
  dns_zone_prefix = "cp.${each.key}"

  snat = false
}

resource "proxmox_virtual_environment_sdn_vnet" "dataplane" {
  id   = "${var.environment_short_name}data"
  zone = proxmox_virtual_environment_sdn_zone_evpn.l3_network.id
  tag  = var.dataplane_vlan_tag
}

# resource "proxmox_virtual_environment_sdn_subnet" "dataplane_metallb_subnet" {
#   cidr    = "10.${var.vxlan_octet["metallb"]}.0.0/24"
#   vnet    = proxmox_virtual_environment_sdn_vnet.dataplane.id
#   gateway = "10.${var.vxlan_octet["metallb"]}.0.1"

# }

resource "proxmox_virtual_environment_sdn_subnet" "dataplane_subnets" {
  for_each        = var.fault_domains
  cidr            = "10.${var.vxlan_octet["dataplane"]}.${each.value.id}.0/24"
  vnet            = proxmox_virtual_environment_sdn_vnet.dataplane.id
  gateway         = "10.${var.vxlan_octet["dataplane"]}.${each.value.id}.1"
  dns_zone_prefix = "dp.${each.key}"

  snat = false
}

# SDN Applier - Applies SDN configuration changes
resource "proxmox_virtual_environment_sdn_applier" "sdn_applier" {
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_sdn_zone_vxlan.l2_overlay,
      proxmox_virtual_environment_sdn_zone_evpn.l3_network,
      proxmox_virtual_environment_sdn_vnet.controlplane,
      proxmox_virtual_environment_sdn_vnet.dataplane,
      proxmox_virtual_environment_sdn_subnet.controlplane_subnets,
      proxmox_virtual_environment_sdn_subnet.dataplane_subnets
    ]
  }

  depends_on = [
    proxmox_virtual_environment_sdn_zone_vxlan.l2_overlay,
    proxmox_virtual_environment_sdn_zone_evpn.l3_network,
    proxmox_virtual_environment_sdn_vnet.controlplane,
    proxmox_virtual_environment_sdn_vnet.dataplane,
    proxmox_virtual_environment_sdn_subnet.controlplane_subnets,
    proxmox_virtual_environment_sdn_subnet.dataplane_subnets,
  ]
}