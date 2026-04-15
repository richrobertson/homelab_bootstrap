variable "environment_name" {
  type = string
}

variable "environment_short_name" {
  type = string
}

variable "cluster_name" {
  description = "The name of the cluster (used for path in repo)"
  type        = string
}

variable "fault_domains" {
  type = map(object({
    id   = number
    name = string
  }))
}

variable "control_plane_network_bridge" {
  type = string
}
variable "control_plane_network_vlan_id" {
  type = number
}
variable "control_plane_subnets_by_fd" {
  type = map(object({
    cidr = string
  }))
}
variable "worker_network_bridge" {
  type = string
}
variable "worker_network_vlan_id" {
  type    = number
  default = null
}

variable "worker_subnets_by_fd" {
  type = map(object({
    cidr = string
  }))
}


variable "dns_auth_sever" {
  type = object({
    ipv4_addresses = list(string)
    ipv6_addresses = list(string)
  })
}

variable "dns_server" {
  type = object({
    ipv4_addresses = list(string)
    ipv6_addresses = list(string)
  })
}

variable "proxmox_ve_nodes" {
  type = list(string)
}

variable "kubernetes_nodes_resources" {
    type = map(object({
        cpu_cores    = number
        memory_in_gb = number
    }))
}

variable "vault_pki_policy_paths" {
  description = "List of Vault policy path configurations for PKI cert-issuer"
  type = list(object({
    path         = string
    capabilities = list(string)
  }))
  default = []
}

variable "vault_pki_role" {
  description = "Vault PKI role configuration for certificate generation"
  type = object({
    allow_any_name    = bool
    allow_bare_domains = bool
    allow_subdomains  = bool
    allowed_domains   = list(string)
  })
  default = {
    allow_any_name    = false
    allow_bare_domains = true
    allow_subdomains  = true
    allowed_domains   = ["myrobertson.net"]
  }
}

variable "enable_talos_cluster_health_check" {
  description = "Whether to run Talos cluster health checks during plan/apply."
  type        = bool
  default     = true
}