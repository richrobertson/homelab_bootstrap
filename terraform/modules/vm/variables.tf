variable "cloud_image_id" {
  description = "ID of the cloud image to download"
  type        = string
}


variable "node_name" {
  description = "The name of the Proxmox node to deploy the VM on"
  type        = string
}

variable "name" {
  description = "Name of the VM"
  type        = string
}

variable "networks" {
  type = list(object({
    bridge      = string
    firewall    = bool
    ip4_address = string
    ip4_gateway = string
    vlan_tag    = number
  }))
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory_in_gb" {
  type    = number
  default = 2

}

variable "disk_size" {
  type    = string
  default = "20"
}

variable "additional_packages" {
  type    = list(string)
  default = []
}

variable "additional_runcmds" {
  type    = list(string)
  default = []
}

variable "ssh_public_key" {
  type    = string
  default = ""
}

variable "ha_enabled" {
  type    = bool
  default = true
}

variable "dns_domain" {
  description = "DNS domain for VM configuration. Example: example.net"
  type        = string
  default     = "example.net"
}

variable "dns_servers" {
  description = "List of DNS servers for VM configuration. Example: [\"203.0.113.1\", \"203.0.113.2\"]"
  type        = list(string)
  default     = ["203.0.113.1", "203.0.113.2"]
}