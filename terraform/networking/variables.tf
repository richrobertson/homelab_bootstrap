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