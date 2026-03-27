
variable "cloud_image_id" {
  description = "ID of the cloud image to download"
  type        = string
}

variable "ssh_public_key" {
  type = string
}

variable "ip4_address" {
  description = "IPv4 address for PowerDNS auth server. Example: 203.0.113.201/24"
  type        = string
  default     = "203.0.113.201/24"
}

variable "ip4_gateway" {
  description = "IPv4 gateway for PowerDNS network. Example: 203.0.113.1"
  type        = string
  default     = "203.0.113.1"
}

variable "network_vlan_id" {
  description = "VLAN ID for PowerDNS network"
  type        = number
  default     = 100
}

variable "network_bridge" {
  description = "Network bridge for PowerDNS VM. Example: vmbr1"
  type        = string
  default     = "vmbr1"
}