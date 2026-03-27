variable "ssh_public_key" {
  description = "SSH public key injected into substrate VMs."
  type        = string
}

variable "substrate_vlan_id" {
  description = "VLAN ID for substrate network. Example: 7"
  type        = number
  default     = 100
}

variable "substrate_network_bridge" {
  description = "Network bridge for substrate VMs. Example: vmbr1"
  type        = string
  default     = "vmbr1"
}

variable "database_ip_address" {
  description = "IP address for database VM. Example: 203.0.113.200/24"
  type        = string
  default     = "203.0.113.200/24"
}

variable "database_ip_gateway" {
  description = "Deprecated: use substrate_ip_gateway. IP gateway for substrate network. Example: 203.0.113.1"
  type        = string
  default     = "203.0.113.1"
}

variable "substrate_ip_gateway" {
  description = "IP gateway for substrate network shared by substrate VMs. Example: 203.0.113.1"
  type        = string
  default     = ""
}

variable "powerdns_auth_ip_address" {
  description = "IP address for PowerDNS auth server. Example: 203.0.113.201/24"
  type        = string
  default     = "203.0.113.201/24"
}

variable "powerdns_recurse_ip_address" {
  description = "IP address for PowerDNS recursive server. Example: 203.0.113.202/24"
  type        = string
  default     = "203.0.113.202/24"
}

variable "root_domain" {
  description = "Root DNS domain used for substrate VM cloud-init search domain."
  type        = string
}