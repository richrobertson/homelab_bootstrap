variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
}

variable "root_domain" {
  description = "Root domain for cluster FQDN. Example: example.net"
  type        = string
  default     = "example.net"
}

variable "node_data" {
  description = "A map of node data"
  type = object({
    controlplanes = map(object({
      install_disk = string
      hostname     = optional(string)
      ip4_address  = string
    }))
    workers = map(object({
      install_disk = string
      hostname     = optional(string)
      ip4_address  = string
    }))
  })
}

variable "vault_pki_secret_backend_path" {
  type = string
}

variable "talos_installer_image" {
  description = "Optional Talos installer image to pin in generated machine config."
  type        = string
  default     = null
}