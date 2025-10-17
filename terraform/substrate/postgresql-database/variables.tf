variable "node_name" {
  description = "The name of the Proxmox node to deploy resources on."
  type        = string
}

variable "ssh_public_key" {
  type = string
}

variable "postgres_password" {
  description = "Password for the postgres user in the database."
  type        = string
}

variable "hostname" {
  description = "The hostname for the VM."
  type        = string
}

variable "ip4_address" {
  type = string
}
variable "ip4_gateway" {
  type = string
}

variable "network_vlan_id" {
  type = string
}

variable "network_bridge" {
  type = string
}

variable "cloud_image_id" {
  description = "ID of the cloud image to download"
  type        = string
}