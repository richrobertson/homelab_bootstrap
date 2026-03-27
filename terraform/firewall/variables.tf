variable "proxmox_ve_nodes" {
  type = list(string)
}

variable "cluster_short_name" {
  type = string
}

variable "lan_network_bridge" {
  type = string
}


variable "wan_network_bridge" {
  type = string
}

variable "wan_network_vlan_tag" {
  description = "The VLAN TAG to use for the network bridge"
  type        = number
  default     = null
}

variable "fw_count" {
  type    = number
  default = 1
}

variable "cpu_cores" {
  type    = number
  default = 4

}

variable "memory_in_gb" {
  type    = number
  default = 4

}

variable "dns_domain" {
  description = "DNS search domain for provisioned VMs."
  type        = string
}

variable "dns_servers" {
  description = "DNS resolver servers for provisioned VMs."
  type        = list(string)
}