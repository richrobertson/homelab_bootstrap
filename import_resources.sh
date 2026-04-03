#!/bin/bash
set -euo pipefail

cd /Users/rich/Documents/GitHub/homelab_bootstrap/terraform
source ~/.bash_profile

echo "=== IMPORTING REMAINING RESOURCES ==="
echo

failed_imports=0

in_state() {
  local address="$1"
  terraform state show "$address" >/dev/null 2>&1
}

safe_import() {
  local address="$1"
  local import_id="$2"
  local label="$3"

  if in_state "$address"; then
    echo "- Skipping $label (already in state)"
    return 0
  fi

  echo "- Importing $label"
  set +e
  output=$(terraform import -var='enable_flux=false' "$address" "$import_id" 2>&1)
  ec=$?
  set -e

  if [ "$ec" -eq 0 ]; then
    echo "  Imported $label"
    return 0
  fi

  if echo "$output" | grep -qi "already managed"; then
    echo "  Skipping $label (already managed)"
    return 0
  fi

  echo "$output"
  return "$ec"
}

import_or_warn() {
  local address="$1"
  local import_id="$2"
  local label="$3"

  if ! safe_import "$address" "$import_id" "$label"; then
    echo "WARNING: Failed import for $label"
    failed_imports=$((failed_imports + 1))
  fi
}

# Import ADCS Certificates (talos secrets)
echo "=== Step 1: ADCS Certificates for Talos Secrets ==="
import_or_warn \
  'module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.etcd.microsoftadcs_certificate.this' \
  '134' \
  'etcd ADCS cert (ID 134)'

import_or_warn \
  'module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.k8s.microsoftadcs_certificate.this' \
  '135' \
  'k8s ADCS cert (ID 135)'

import_or_warn \
  'module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.k8s_aggregator.microsoftadcs_certificate.this' \
  '136' \
  'k8s_aggregator ADCS cert (ID 136)'

import_or_warn \
  'module.kubernetes-cluster[0].module.talos_cluster.module.secrets.module.os.microsoftadcs_certificate.this' \
  '137' \
  'os ADCS cert (ID 137)'
echo

# Import DNS Records (PowerDNS)
echo "=== Step 2: DNS Records ==="

# Control plane host records (for each failure domain)
for fd in fd-0 fd-1 fd-2; do
  zone="cp.${fd}.staging.myrobertson.net."
  name="k8s-stg-cp-$(echo $fd | cut -d'-' -f2).cp.${fd}.staging.myrobertson.net."
  import_or_warn \
    "module.kubernetes-cluster[0].module.nodes.module.control_plane_host_records[\"${fd}\"].powerdns_record.records" \
    "${zone}|${name}|A" \
    "control_plane_host_records[$fd]"
done
echo

# Data plane worker records (for each failure domain)
for fd in fd-0 fd-1 fd-2; do
  zone="dp.${fd}.staging.myrobertson.net."
  name="k8s-stg-worker-$(echo $fd | cut -d'-' -f2).dp.${fd}.staging.myrobertson.net."
  import_or_warn \
    "module.kubernetes-cluster[0].module.nodes.module.data_plane_host_records[\"${fd}\"].powerdns_record.records" \
    "${zone}|${name}|A" \
    "data_plane_host_records[$fd]"
done
echo

# Control plane subdomain DNS records
zone="staging.myrobertson.net."

# HTTPS record
import_or_warn \
  "module.kubernetes-cluster[0].module.nodes.module.control_plane_subdomain_https.powerdns_record.records" \
  "${zone}|cp.staging.myrobertson.net.|HTTPS" \
  "control_plane_subdomain_https"

# IPv4 (A) record
import_or_warn \
  "module.kubernetes-cluster[0].module.nodes.module.control_plane_subdomain_ipv4.powerdns_record.records" \
  "${zone}|cp.staging.myrobertson.net.|A" \
  "control_plane_subdomain_ipv4"
echo

echo "=== Step 3: Talos Machine Configuration Apply (fd-2 only) ==="
# Note: These may need special handling depending on actual resource IDs in the provider

# Control plane for fd-2  
import_or_warn \
  'module.kubernetes-cluster[0].module.talos_cluster.talos_machine_configuration_apply.controlplane["fd-2"]' \
  'machine_configuration_apply' \
  'controlplane machine configuration apply (fd-2)'

# Worker for fd-2
import_or_warn \
  'module.kubernetes-cluster[0].module.talos_cluster.talos_machine_configuration_apply.worker["fd-2"]' \
  'machine_configuration_apply' \
  'worker machine configuration apply (fd-2)'
echo

echo "=== All imports completed ==="
echo "Running plan to verify no 'will be created' resources remain..."
set +e
terraform plan -no-color | grep -E "^Plan:|will be created|will be destroyed|must be replaced" | head -n 10
set -e

if [ "$failed_imports" -gt 0 ]; then
  echo
  echo "Completed with $failed_imports import warning(s)."
  exit 1
fi
