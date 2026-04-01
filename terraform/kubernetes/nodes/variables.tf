variable "proxmox_ve_nodes" {
  type = list(string)
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
  type = number
}

variable "worker_network_bridge" {
  type = string
}
variable "worker_network_vlan_id" {
  type = number
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

variable "control_plane_cloud_image_id" {
  description = "Cloud image used for Talos control plane VMs."
  type        = string
  default     = "cephfs:import/nocloud-amd64-2.raw"
}

variable "worker_cloud_image_id" {
  description = "Cloud image used for Talos worker VMs."
  type        = string
  default     = "cephfs:import/nocloud-amd64-2.raw"
}

variable "worker_host_pci_devices" {
  description = "Host PCI devices to attach to every worker VM."
  type = list(object({
    device   = string
    id       = optional(string)
    mapping  = optional(string)
    mdev     = optional(string)
    pcie     = optional(bool)
    rombar   = optional(bool)
    rom_file = optional(string)
    xvga     = optional(bool)
  }))
  default = []
}

variable "fault_domains" {
  type = map(object({
    id   = number
    name = string
  }))
}

variable "dns_auth_server" {
  type = object({
    ipv4_addresses = list(string)
    ipv6_addresses = list(string)
  })
}

variable "authoritative_nameserver" {
  description = "Primary authoritative nameserver for delegated cluster zones. Example: ns1.example.net"
  type        = string
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