variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
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
