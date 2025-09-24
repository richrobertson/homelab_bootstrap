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
    bridge = string
    firewall = bool
    ip4_address  = string
    ip4_gateway  = string
    vlan_tag      = string
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