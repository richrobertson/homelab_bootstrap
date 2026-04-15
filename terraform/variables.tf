variable "enable_talos_cluster_health_check" {
  description = "Whether to run Talos cluster health checks during plan/apply."
  type        = bool
  default     = true
}

variable "volsync_s3_settings_vault_path" {
  description = "Vault path to a VolSync S3 secret containing AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and RESTIC_REPOSITORY."
  type        = string
  default     = "secret/volsync/prod/plex-config-ceph"
}

variable "volsync_s3_region_override" {
  description = "Optional override for the AWS region derived from VolSync RESTIC_REPOSITORY."
  type        = string
  default     = null
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
