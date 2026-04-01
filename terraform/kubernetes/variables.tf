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

variable "organization" {
  description = "Organization name for PKI subjects. Defaults to root_domain when null."
  type        = string
  default     = null
  nullable    = true
}

variable "authoritative_nameserver" {
  description = "Primary authoritative nameserver for delegated cluster zones. Example: ns1.example.net"
  type        = string
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

variable "talos_installer_image" {
  description = "Optional Talos installer image to pin in generated machine config."
  type        = string
  default     = null
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