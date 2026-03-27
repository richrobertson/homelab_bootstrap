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
  description = "DNS zone for gssapi updates. Example: example.com"
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