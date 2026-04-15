variable "proxmox_ve_nodes" {
  type = list(string)
}

variable "environment_name" {
  type = string
}

variable "cluster_short_name" {
  type = string
}

variable "control_plane_cpu_cores" {
  type    = number
  default = 2
}

variable "control_plane_memory_in_gb" {
  type    = number
  default = 2

}

variable "worker_cpu_cores" {
  type    = number
  default = 4

}

variable "worker_memory_in_gb" {
  type    = number
  default = 8

}

variable "control_plane_network_bridge" {
  type = string
}

variable "control_plane_network_vlan_id" {
  type    = number
  default = null
}

variable "worker_network_bridge" {
  type = string
}
variable "worker_network_vlan_id" {
  type    = number
  default = null
}


variable "control_plane_subnets_by_fd" {
  type = map(object({
    cidr = string
  }))
}

variable "worker_subnets_by_fd" {
  type = map(object({
    cidr = string
  }))
}


variable "fault_domains" {
  type = map(object({
    id   = number
    name = string
  }))
}

variable "dns_auth_sever" {
  type = object({
    ipv4_addresses = list(string)
    ipv6_addresses = list(string)
  })
}

variable "dns" {
  type = object({
    domain = string
    servers = object({
      ipv4_addresses = list(string)
      ipv6_addresses = list(string)
    })
  })
}

variable "worker_gpu_hostpci" {
  description = "List of host PCI devices to passthrough to fd-0 worker node for GPU support (e.g., Intel iGPU)"
  type = list(object({
    device  = string
    mapping = optional(string)
  }))
  default = null
}