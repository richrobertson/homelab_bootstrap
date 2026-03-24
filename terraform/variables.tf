variable "proxmox_insecure" {
  description = "Skip TLS verification for Proxmox API (use only in explicitly trusted dev environments)."
  type        = bool
  default     = false
}