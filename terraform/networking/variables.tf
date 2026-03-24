variable "nodes" {
  description = "List of Proxmox nodes for the VXLAN zone"
  type        = set(string)
}

variable "fault_domains" {
  type = map(object({
    id   = number
    name = string
  }))
}

variable "environment_name" {
  type = string
}

variable "environment_short_name" {
  type = string
}

variable "dns_server" {
  type = string
}

variable "vrf_vxlan" {
  type = number
}

variable "dataplane_vlan_tag" {
  description = "VLAN tag for the dataplane network"
  type        = number
}
variable "controlplane_vlan_tag" {
  description = "VLAN tag for the controlplane network"
  type        = number
}

variable "vxlan_octet" {
  description = "Map of octets for VXLAN subnets"
  type        = map(number)
}