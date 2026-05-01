# Talos etcd Backups

Talos etcd backup support has two pieces:

- Terraform creates a single shared S3 bucket from the production workspace:
  `myrobertson-homelab-talos-etcd-backups`.
- Terraform writes per-cluster backup configuration to Vault at
  `secret/talos/backup/<env-suffix>`, including Talos config, endpoint, AWS
  credentials, bucket, and prefix.

Implementation files:

- [talos_etcd_backup_bucket.tf](../../terraform/talos_etcd_backup_bucket.tf)
- [talos_backup_vault_secret.tf](../../terraform/talos_backup_vault_secret.tf)
- [scripts/backup_talos_etcd_to_s3.sh](../../scripts/backup_talos_etcd_to_s3.sh)

## Scripted Backup

Run the backup script from repository root:

```bash
bash scripts/backup_talos_etcd_to_s3.sh
```

The script:

1. Detects the current Terraform workspace.
2. Exports `talosconfig` from Terraform output.
3. Reads S3 credentials from `secret/volsync/prod/plex-config-ceph` by default.
4. Takes an etcd snapshot with `talosctl`.
5. Uploads the snapshot to
   `s3://myrobertson-homelab-talos-etcd-backups/<env-prefix>/`.

Required CLIs on the runner:

- `terraform`
- `talosctl`
- `vault`
- `aws`

## Jenkins Integration

The Jenkins pipeline runs the backup script on `main` for non-PR builds after
Terraform apply.

## Related Documents

- [Common Terraform operations](common-terraform-operations.md)
- [kubernetes/talos component](../../terraform/kubernetes/talos/README.md)
- [Terraform root](../../terraform/README.md)
