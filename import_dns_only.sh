#!/bin/bash
set -euo pipefail

cd /Users/rich/Documents/GitHub/homelab_bootstrap/terraform
source ~/.bash_profile

echo "=== IMPORTING DNS RECORDS ONLY ==="
echo "Note: PowerDNS record IDs are in format: zone|name|type"
echo

# Control plane host records (for each failure domain)
echo "=== Control Plane Host Records ==="
for fd in fd-0 fd-1 fd-2; do
  zone="cp.${fd}.staging.myrobertson.net."
  name="k8s-stg-cp-$(echo $fd | cut -d'-' -f2).cp.${fd}.staging.myrobertson.net."
  record_id="${zone}|${name}|A"  
  echo "Importing control_plane_host_records[$fd]..."
  terraform import -var='enable_flux=false' \
    "module.kubernetes-cluster[0].module.nodes.module.control_plane_host_records[\"${fd}\"].powerdns_record.records" \
    "$record_id" && echo "  ✓ Success" || echo "  ✗ Failed (may already be imported)"
done
echo

# Data plane worker records (for each failure domain)
echo "=== Data Plane Worker Records ==="
for fd in fd-0 fd-1 fd-2; do
  zone="dp.${fd}.staging.myrobertson.net."
  name="k8s-stg-worker-$(echo $fd | cut -d'-' -f2).dp.${fd}.staging.myrobertson.net."
  record_id="${zone}|${name}|A"
  echo "Importing data_plane_host_records[$fd]..."
  terraform import -var='enable_flux=false' \
    "module.kubernetes-cluster[0].module.nodes.module.data_plane_host_records[\"${fd}\"].powerdns_record.records" \
    "$record_id" && echo "  ✓ Success" || echo "  ✗ Failed (may already be imported)"
done
echo

# Control plane subdomain DNS records
echo "=== Control Plane Subdomain Records ==="
zone="staging.myrobertson.net."

# HTTPS record
echo "Importing control_plane_subdomain_https..."
terraform import -var='enable_flux=false' \
  "module.kubernetes-cluster[0].module.nodes.module.control_plane_subdomain_https.powerdns_record.records" \
  "${zone}|cp.staging.myrobertson.net.|HTTPS" && echo "  ✓ Success" || echo "  ✗ Failed (may already be imported)"

# IPv4 (A) record
echo "Importing control_plane_subdomain_ipv4..."
terraform import -var='enable_flux=false' \
  "module.kubernetes-cluster[0].module.nodes.module.control_plane_subdomain_ipv4.powerdns_record.records" \
  "${zone}|cp.staging.myrobertson.net.|A" && echo "  ✓ Success" || echo "  ✗ Failed (may already be imported)"
echo

echo "=== DNS Import Complete ==="
