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
    vlan_tag    = string
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
  description = "The size of the VM disk (e.g., '20G')"
  type        = string
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOWOeC6oOqvDBnVpY+DU8h78cXVd2EiE6NhrCthKsm7/ rich@myrobertson.com"
}

variable "additional_packages" {
  description = "Additional packages to install in the VM"
  type        = list(string)
  default     = []
}

variable "additional_runcmds" {
  type    = list(string)
  default = []
}

variable "ansible_playbook_name" {
  type    = string
  default = ""
}

variable "github_token" {
  type    = string
  default = ""
}

variable "display_type" {
  type    = string
  default = "serial0"
}

variable "dns" {
  type = object({
    domain  = string
    servers = list(string)
  })
  default = {
    domain  = "myrobertson.net"
    servers = ["192.168.7.202"]
  }
}

variable "skip_user_data_file" {
  type    = bool
  default = false
}

variable "ha_enabled" {
  type    = bool
  default = false
}

variable "protect_from_destroy" {
  type    = bool
  default = false
}