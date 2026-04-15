# Write per-cluster Talos etcd backup configuration to Vault.
# VSO (vault-secrets-operator) running inside each cluster reads this secret
# and surfaces it as a K8s Secret consumed by the talos-etcd-backup CronJob.
resource "vault_kv_secret_v2" "talos_backup_config" {
  count = length(module.kubernetes-cluster)

  mount = "secret"
  name  = "talos/backup/${local.talos_backup_env_suffix}"

  data_json = jsonencode({
    TALOS_CONFIG          = module.kubernetes-cluster[0].talosconfig
    TALOS_ENDPOINT        = cidrhost(module.networking[0].controlplane_network.subnets_by_fd["fd-0"].cidr, 2)
    ENV_NAME              = local.env.environment_name
    AWS_ACCESS_KEY_ID     = data.vault_generic_secret.volsync_s3_settings.data["AWS_ACCESS_KEY_ID"]
    AWS_SECRET_ACCESS_KEY = data.vault_generic_secret.volsync_s3_settings.data["AWS_SECRET_ACCESS_KEY"]
    AWS_DEFAULT_REGION    = local.volsync_s3_region
    S3_BUCKET             = local.talos_backup_shared_bucket_name
    S3_PREFIX             = local.talos_backup_env_suffix
  })
}
