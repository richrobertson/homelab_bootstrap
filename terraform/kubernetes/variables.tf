variable "environment_name" {
  type = string
}

variable "environment_short_name" {
  type = string
}

variable "cluster_name" {
  description = "The name of the cluster (used for path in repo)"
  type        = string
}

variable "fault_domains" {
  type = map(object({
    id   = number
    name = string
  }))
}

variable "control_plane_network_bridge" {
  type = string
}
variable "control_plane_subnets_by_fd" {
  type = map(object({
    cidr = string
  }))
}
variable "worker_network_bridge" {
  type = string
}
variable "worker_network_vlan_id" {
  type    = number
  default = null
}

variable "worker_subnets_by_fd" {
  type = map(object({
    cidr = string
  }))
}


variable "dns_auth_sever" {
  type = object({
    ipv4_addresses = list(string)
    ipv6_addresses = list(string)
  })
}

variable "dns_server" {
  type = object({
    ipv4_addresses = list(string)
    ipv6_addresses = list(string)
  })
}

variable "proxmox_ve_nodes" {
  type = list(string)
}