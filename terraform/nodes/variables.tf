variable "proxmox_ve_nodes" {
  type = list(string)
}

variable "cluster_short_name" {
  type = string
}

variable "network_bridge" {
  description = "The bridge to use for control plane & worker VMs"
  type        = string
}

variable "network_vlan_id" {
  description = "The VLAN ID to use for the network bridge"
  type        = number
  default     = null
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
  default = 1
}

variable "worker_cpu_cores" {
  type    = number
  default = 4

}

variable "worker_memory_in_gb" {
  type    = number
  default = 8

}