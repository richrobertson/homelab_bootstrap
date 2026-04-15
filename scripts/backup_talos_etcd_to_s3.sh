#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${REPO_ROOT}/terraform"

VOLSYNC_S3_VAULT_PATH="${VOLSYNC_S3_VAULT_PATH:-secret/volsync/prod/plex-config-ceph}"
TALOS_BACKUP_BUCKET="${TALOS_BACKUP_BUCKET:-myrobertson-homelab-talos-etcd-backups}"

need_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

need_cmd terraform
need_cmd talosctl
need_cmd vault
need_cmd aws

workspace="${TERRAFORM_WORKSPACE:-}"
if [[ -z "${workspace}" ]]; then
  workspace="$(cd "${TERRAFORM_DIR}" && terraform workspace show)"
fi

prefix="${workspace}"
case "${workspace}" in
  staging)
    prefix="stage"
    ;;
  production|prod)
    prefix="prod"
    ;;
esac

restic_repository="$(vault kv get -field=RESTIC_REPOSITORY "${VOLSYNC_S3_VAULT_PATH}")"
access_key_id="$(vault kv get -field=AWS_ACCESS_KEY_ID "${VOLSYNC_S3_VAULT_PATH}")"
secret_access_key="$(vault kv get -field=AWS_SECRET_ACCESS_KEY "${VOLSYNC_S3_VAULT_PATH}")"

region="${VOLSYNC_S3_REGION_OVERRIDE:-}"
if [[ -z "${region}" ]]; then
  # Extract aws region from RESTIC_REPOSITORY endpoint, fallback to us-west-2.
  if [[ "${restic_repository}" =~ s3[.]([^.]+)[.]amazonaws[.]com ]]; then
    region="${BASH_REMATCH[1]}"
  else
    region="us-west-2"
  fi
fi

export AWS_ACCESS_KEY_ID="${access_key_id}"
export AWS_SECRET_ACCESS_KEY="${secret_access_key}"
export AWS_DEFAULT_REGION="${region}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

talosconfig_path="${workdir}/talosconfig"
snapshot_name="etcd-${workspace}-$(date -u +%Y%m%dT%H%M%SZ).db"
snapshot_path="${workdir}/${snapshot_name}"
s3_key="${prefix}/${snapshot_name}"

cd "${TERRAFORM_DIR}"
terraform workspace select "${workspace}" >/dev/null
terraform output -raw talosconfig > "${talosconfig_path}"

# Use default nodes/endpoints embedded in talosconfig output from terraform.
talosctl --talosconfig "${talosconfig_path}" etcd snapshot "${snapshot_path}"

aws s3 cp "${snapshot_path}" "s3://${TALOS_BACKUP_BUCKET}/${s3_key}"

echo "Talos etcd snapshot uploaded to s3://${TALOS_BACKUP_BUCKET}/${s3_key}"