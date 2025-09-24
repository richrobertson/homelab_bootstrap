

provider "flux" {
  kubernetes = {
    host                   = var.kubernets_cluster_endpoint
    client_certificate     = var.kubernets_client_certificate
    client_key             = var.kubernets_client_key
    cluster_ca_certificate = var.kubernets_cluster_ca_certificate
  }
  git = {
    url = "https://github.com/${var.github_org}/${var.github_repository}.git"
    http = {
      username = "git" # This can be any string when using a personal access token
      password = var.github_token
    }
  }
}

provider "github" {
  owner = var.github_org
  token = var.github_token
}