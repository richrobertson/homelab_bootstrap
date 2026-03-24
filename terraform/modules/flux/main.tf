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
    github = {
      source  = "integrations/github"
      version = ">= 6.1"
    }
  }
}

# ==========================================
# Initialise a Github project
# ==========================================

/* resource "github_repository" "this" {
  name        = var.github_repository
  description = var.github_repository
  visibility  = "private"
  auto_init   = true # This is extremely important as flux_bootstrap_git will not work without a repository that has been initialised
  lifecycle {
   prevent_destroy = true
 }
} */

data "github_repository" "this" {
  name = var.github_repository
}

# ==========================================
# Bootstrap cluster
# ==========================================

resource "flux_bootstrap_git" "this" {
  depends_on = [data.github_repository.this]

  embedded_manifests = true
  path               = "clusters/${var.cluster_name}"
}
