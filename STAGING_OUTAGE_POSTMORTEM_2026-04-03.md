# Staging Kubernetes Outage Postmortem and Recovery Runbook

Date: 2026-04-03
Environment: staging
Primary impact: Staging control plane instability and degraded cluster health
Business risk: High (patterns observed in staging can cause production outage if repeated)

## 1) Executive Summary

A staging outage occurred where control-plane nodes appeared unhealthy and cluster membership dropped. Initial signals looked like missing IP addressing, but investigation showed IPs existed and the deeper failure was network attachment and link-state related on Proxmox-hosted control-plane VMs.

The highest-confidence technical finding is that control-plane tap interfaces existed but were detached from the staging control-plane bridge on all three Proxmox nodes. After reattaching tap devices and forcing VM NIC link state up in QEMU, node reachability recovered and control-plane APIs resumed.

Overnight, the environment appears to have stabilized further, likely due to delayed reconciliation/restart/convergence in hypervisor networking and VM link state.

## 2) What We Did (Consolidated Activity Log)

### 2.1 Investigation path

1. Validated historical Terraform/Talos configuration and commit history.
2. Confirmed Talos machine configuration historically did not rely on explicit static interface configuration for node IPs; IPs were typically provided by Proxmox cloud-init.
3. Reviewed runtime symptoms:
   - Kubelet unhealthy on at least one staging CP node.
   - DNS timeouts seen from node perspective.
   - Cluster showing reduced machine membership.
4. Investigated Proxmox networking and found:
   - Control-plane taps existed as tuntap devices.
   - Those taps were not attached to staging control-plane bridge (stgctr).
   - Worker taps were attached correctly to worker bridge (stgdata).
5. Applied network interface repair on hosts:
   - Attached detached CP taps to stgctr.
   - Set tap MTU to 1450 and interfaces up.
6. Confirmed one node still did not answer ARP until VM NIC link was explicitly enabled with QEMU monitor command:
   - set_link net0 on
7. Repeated link-up operation for all three CP VMs and verified per-node local reachability improved.

### 2.2 Commands/actions executed (representative)

- Host-side bridge attach:
  - ip link set tap206i0 master stgctr
  - ip link set tap205i0 master stgctr
  - ip link set tap217i0 master stgctr
- Link and MTU normalization:
  - ip link set tapXXXi0 mtu 1450
  - ip link set tapXXXi0 up
- VM NIC link-state repair (QEMU monitor):
  - set_link net0 on
- Verification checks included:
  - bridge link show
  - ip tuntap show
  - ip neigh show
  - curl against kube-apiserver 6443 (401 confirms API up)
  - ping tests in vrf_stgl3 context

### 2.3 Key observed before/after behavior

Before:
- CP nodes unstable or unreachable from expected paths.
- Kubelet unhealthy signal.
- Reduced cluster membership.

After repair steps:
- CP taps present in bridge forwarding state.
- ARP/ICMP reachability restored where link-state was forced on.
- Kubernetes API on CP nodes returned Unauthorized (expected unauthenticated response), indicating API process reachable.

## 3) Root Cause Analysis

## 3.1 Primary root cause

Control-plane VM tap interfaces were detached from the staging control-plane bridge (stgctr) across multiple Proxmox hosts.

This prevented normal L2 forwarding for control-plane VM traffic, causing control-plane network isolation symptoms despite VMs being powered on and configured.

## 3.2 Contributing cause

At least one VM NIC link state remained effectively down/inactive from VM perspective even after tap reattachment, requiring explicit QEMU monitor action:

- set_link net0 on

This indicates that bridge reattachment alone may not fully restore traffic if QEMU device link state is not reasserted.

## 3.3 Secondary factors

- DNS/routing path complexity in VRF/EVPN environment increased time to isolate true failure mode.
- Symptom overlap (DNS timeout, kubelet unhealthy, partial API behavior) made initial diagnosis appear like Talos config or DNS-only issue.

## 3.4 Why this looked like an IP configuration issue

Even when node IP data existed in cloud-init and runtime config, detached tap interfaces made nodes effectively unreachable in relevant paths. This creates a false-positive perception of missing IP assignment.

## 3.5 Recovery mechanics (why it seemed repaired overnight)

Most probable explanations:

1. Hypervisor/network reconciliation or host-level service refresh re-established expected attachment state.
2. VM restarts/reloads reapplied NIC state.
3. EVPN/neighbor state converged after physical/logical attachment was restored.

## 4) Lessons Learned

1. Do not trust first symptom framing.
   - "No IP" can actually be L2 attachment failure.
2. For Proxmox SDN outages, verify tap-to-bridge attachment early.
   - ip tuntap show + bridge link show should be first-line checks.
3. Include VM link-state verification in triage.
   - If tap is attached but VM still silent, verify QEMU NIC link status and force link on if needed.
4. Separate control-plane and worker path checks.
   - Worker success can mask CP-only bridge failures.
5. Preserve forensic trail during incident.
   - Document exact host, vmid, tap names, and command outputs.
6. Stage and production should share health guardrails.
   - If this pattern reaches production, blast radius is severe.

## 5) Prevention and Hardening Actions

### 5.1 Immediate safeguards

1. Add automated check script to validate expected CP/worker taps are attached to the correct bridge on all Proxmox nodes.
2. Alert if any expected tap is missing from bridge forwarding state.
3. Alert if kube-apiserver reachability drops on any CP node.

### 5.2 Near-term engineering actions

1. Add periodic host-level reconciliation for critical VM bridge memberships.
2. Add runbook step to verify and repair QEMU link state when tap attach alone does not recover traffic.
3. Define incident SLO for staging control-plane degradation and page criteria.

### 5.3 Production risk controls

1. Implement pre-change safety check for bridge membership and CP reachability in production before any network/SDN changes.
2. Require explicit rollback plan for SDN/bridge changes.
3. Add game day scenario: detached tap simulation + timed recovery drill.

## 6) Runbook: Proxmox/Talos Control-Plane Network Outage

## Scope
Use this runbook when Kubernetes control-plane nodes become unhealthy/unreachable and symptoms suggest IP/DNS/routing/network instability.

## Inputs required

- Proxmox host list
- VMID to role mapping (cp-0/cp-1/cp-2)
- Expected bridges (stgctr for CP, stgdata for workers)
- Expected VRF and MTU values

## Phase A: Triage (5-10 min)

1. Confirm impact:
   - Check cluster membership and CP health endpoints.
2. Verify VM runtime state:
   - qm status <vmid>
3. Verify tap existence:
   - ip tuntap show | grep tap<vmid>i0
4. Verify tap bridge membership:
   - bridge link show | grep tap<vmid>i0
5. Verify local bridge config:
   - ip link show <bridge>
   - cat /sys/devices/virtual/net/<bridge>/bridge/vlan_filtering

Decision:
- If tap exists but is not in bridge: go to Phase B.
- If tap is in bridge but VM still unreachable: go to Phase C.

## Phase B: Tap reattachment repair

1. Attach tap to bridge:
   - ip link set tap<vmid>i0 master <bridge>
2. Normalize MTU and state:
   - ip link set tap<vmid>i0 mtu <expected_mtu>
   - ip link set tap<vmid>i0 up
3. Validate forwarding:
   - bridge link show | grep tap<vmid>i0

Repeat for all impacted hosts/nodes.

## Phase C: VM NIC link-state repair

1. Open QEMU monitor:
   - qm monitor <vmid>
2. Force NIC link on:
   - set_link net0 on
3. Validate:
   - ARP entry appears for VM IP
   - ping/port checks succeed from correct VRF context

## Phase D: Control-plane recovery verification

1. From proper routing context, verify each CP node:
   - TCP 6443 reachable (expect 401 on unauthenticated request)
   - TCP 50000 reachable (Talos API)
2. Confirm cluster membership returns to expected count.
3. Confirm kubelet/node status transitions healthy.

## Phase E: Post-incident actions

1. Capture exact host/vmid/tap mapping and final state.
2. Open corrective action tickets for automation/alerting.
3. Run next-day regression check after planned/unplanned reboot.

## 7) Open Questions

1. What exact event detached CP taps from stgctr on all three hosts?
2. Why did this affect CP path while worker path remained intact?
3. Which host/service event can leave QEMU NIC link state requiring manual set_link?
4. Can Proxmox SDN reconciliation be made deterministic for this topology?

## 8) Branching and Repository Safety Plan

Goal: Preserve all current work before any cleanup of main branch.

Planned sequence:

1. Create a safety snapshot branch from current HEAD with all local changes.
2. Commit current working tree (including this document) to that branch.
3. Switch to main.
4. Reset local main to origin/main.
5. Regroup from clean main while retaining full forensic and code snapshot in the safety branch.

Suggested branch name:

- incident/staging-outage-snapshot-2026-04-03

## 9) Production Outage Prevention Statement

We cannot accept this failure pattern in production. Bridge/tap attachment and VM link-state validation must become mandatory health checks with alerting and pre-change gates before production networking modifications.
