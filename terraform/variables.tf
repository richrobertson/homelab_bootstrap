variable "proxmox_endpoint" {
  description = "URL endpoint for Proxmox API. Example: https://pve.example.com:8006/api2/json"
  type        = string
  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "Proxmox endpoint must use HTTPS."
  }
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for Proxmox API (use only in explicitly trusted dev environments)."
  type        = bool
  default     = false
}

variable "dns_zone" {
  description = "DNS zone name for infrastructure records. Example: example.com"
  type        = string
}

variable "dns_update_server" {
  description = "DNS server hostname/IP that accepts dynamic updates. Example: dns01.example.com"
  type        = string
}

variable "dns_realm" {
  description = "Kerberos realm for DNS gssapi authentication. Example: EXAMPLE.COM"
  type        = string
}

variable "adcs_host" {
  description = "Hostname of the Microsoft ADCS server. Example: dc1.example.com"
  type        = string
}

variable "root_domain" {
  description = "Root DNS domain used for VM cloud-init search domain. Example: example.net"
  type        = string
}

variable "default_dns_servers" {
  description = "Default DNS resolver server IPs used for VM cloud-init."
  type        = list(string)
}