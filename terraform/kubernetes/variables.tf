variable "environment_name" {
  type = string
}

variable "environment_short_name" {
  type = string
}

variable "root_domain" {
  description = "Root domain for the cluster infrastructure. Example: example.net"
  type        = string
  default     = "example.net"
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
variable "control_plane_network_vlan_id" {
  type = number
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
  type = number
}

variable "worker_subnets_by_fd" {
  type = map(object({
    cidr = string
  }))
}


variable "dns_auth_server" {
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

variable "kubernetes_nodes_resources" {
  type = map(object({
    cpu_cores    = number
    memory_in_gb = number
  }))
}