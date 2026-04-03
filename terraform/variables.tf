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
  default     = "example.net"
}

variable "default_dns_servers" {
  description = "Default DNS resolver server IPs used for VM cloud-init."
  type        = list(string)
}

variable "github_repository" {
  description = "GitHub repository for Flux bootstrap. Accepts owner/repo or repo name."
  type        = string
  default     = "rich/homelab_bootstrap"
}

variable "enable_flux" {
  description = "Enable Flux module and active provider wiring. Set false for maintenance imports when kubernetes provider inputs are not yet known."
  type        = bool
  default     = true
}