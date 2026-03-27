variable "proxmox_ve_nodes" {
  type = list(string)
}

variable "cluster_short_name" {
  type = string
}

variable "control_plane_count" {
  type    = number
  default = 3
}

variable "control_plane_cpu_cores" {
  type    = number
  default = 2
}

variable "control_plane_memory_in_gb" {
  type    = number
  default = 2
}

variable "worker_count" {
  type    = number
  default = 3
}

variable "worker_cpu_cores" {
  type    = number
  default = 4
}

variable "worker_memory_in_gb" {
  type    = number
  default = 8
}

variable "network_bridge" {
  type = string
}

variable "network_vlan_id" {
  type = number
}

variable "dns_domain" {
  description = "DNS search domain for provisioned VMs."
  type        = string
}

variable "dns_servers" {
  description = "DNS resolver servers for provisioned VMs."
  type        = list(string)
}
