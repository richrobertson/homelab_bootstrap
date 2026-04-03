# Flux Module
#
# Bootstraps GitOps management for the cluster using Flux and GitHub integration.

# -----------------------------
# GitHub Repository Data Source
# Ensures the target GitHub repository exists for Flux bootstrap.
# -----------------------------
# -----------------------------
# Flux Bootstrap Resource
# Bootstraps the cluster with Flux, pointing to the GitHub repository.
# -----------------------------
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = ">= 1.2"
    }
  }
}

# ==========================================
# Bootstrap cluster
# ==========================================

resource "flux_bootstrap_git" "this" {
  embedded_manifests = true
  path               = "clusters/${var.cluster_name}"
}
