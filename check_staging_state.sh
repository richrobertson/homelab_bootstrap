#!/bin/bash
set -euo pipefail

cd /Users/rich/Documents/GitHub/homelab_bootstrap/terraform
source ~/.bash_profile

echo "=== CHECKING STAGING ENVIRONMENT STATE ==="
echo
echo "Active workspace:"
terraform workspace show
echo

old_count=0
new_count=0

count_in_text() {
  local text="$1"
  local pattern="$2"
  local count
  count=$(printf '%s\n' "$text" | grep -c "$pattern" || true)
  echo "${count:-0}"
}

echo "=== OLD unindexed resource paths (if they exist) ==="
if old_paths=$(terraform state list 2>/dev/null | grep -E "^module\.kubernetes-cluster\.(module\.(vault_pki|talos_cluster|nodes)|microsoftadcs)"); then
  echo "$old_paths"
  old_count=$(echo "$old_paths" | wc -l | tr -d ' ')
else
  echo "  (none found - good!)"
fi
echo

echo "=== NEW indexed resource paths (should exist or be imported) ==="
if new_paths=$(terraform state list 2>/dev/null | grep -E "^module\.kubernetes-cluster\[0\]\.(module\.(vault_pki|talos_cluster|nodes)|microsoftadcs)"); then
  echo "$new_paths"
  new_count=$(echo "$new_paths" | wc -l | tr -d ' ')
else
  echo "  (none found yet - need to import)"
fi
echo

echo "=== ADCS Certificate status ==="
echo "Total ADCS certs in state:"
state_list=$(terraform state list 2>/dev/null || true)
count_in_text "$state_list" "microsoftadcs"
echo
echo "Detailed ADCS resources:"
echo "$state_list" | grep "microsoftadcs" || echo "  (none found)"
echo

echo "=== PLAN CHECK ==="
set +e
plan_output=$(terraform plan -var='enable_flux=false' -no-color 2>&1)
plan_ec=$?
set -e
creates=$(count_in_text "$plan_output" "will be created")
destroys=$(count_in_text "$plan_output" "will be destroyed")
updates=$(count_in_text "$plan_output" "will be updated")
echo "Will create:  $creates"
echo "Will destroy: $destroys"
echo "Will update:  $updates"
echo "Plan exit:    $plan_ec"

if [ "$old_count" -gt 0 ] && [ "$new_count" -gt 0 ]; then
  echo
  echo "⚠ WARNING: Both old and new resource addressing schemes are present in state."
  echo "  This can indicate partial migrations and duplicate-management risk."
fi

if echo "$plan_output" | grep -q "will be destroyed"; then
  echo
  echo "WARNING: Resources will be destroyed!"
  echo "$plan_output" | grep -B2 "will be destroyed" | head -20
fi

if echo "$plan_output" | grep -q "must be replaced"; then
  echo
  echo "NOTICE: Some resources are marked for replacement."
  echo "$plan_output" | grep -B2 "must be replaced" | head -20
fi

echo
echo "=== RECOMMENDATION ==="
if [ "$destroys" -gt 0 ]; then
  echo "DO NOT apply yet - resources would be destroyed."
  echo "   Check if old unindexed paths exist and need cleanup."
else
  echo "Safe to apply with respect to destroy count: no resources will be destroyed."
fi
