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
    allow_any_name     = bool
    allow_bare_domains = bool
    allow_subdomains   = bool
    allowed_domains    = list(string)
  })
  default = {
    allow_any_name     = false
    allow_bare_domains = true
    allow_subdomains   = true
    allowed_domains    = ["myrobertson.net"]
  }
}

variable "worker_gpu_hostpci" {
  description = "List of host PCI devices for GPU passthrough to fd-0 worker node (Intel iGPU)"
  type = list(object({
    device  = string
    mapping = optional(string)
  }))
  default = null
}

variable "talos_etcd_backup_s3" {
  description = "Optional Talos etcd backup configuration for S3. Set to null to disable managed etcd backups."
  type        = any
  default     = null
  sensitive   = true

  validation {
    condition = var.talos_etcd_backup_s3 == null || alltrue([
      can(var.talos_etcd_backup_s3.bucket),
      can(var.talos_etcd_backup_s3.region),
      can(var.talos_etcd_backup_s3.access_key_id),
      can(var.talos_etcd_backup_s3.secret_access_key)
    ])
    error_message = "talos_etcd_backup_s3 must include bucket, region, access_key_id, and secret_access_key when set."
  }
}
