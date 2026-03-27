

locals {
  kubeconfig = yamldecode(module.nodes.kubeconfig)
}

provider "dns" {
  update {
    server = var.dns_zone
    gssapi {
      realm    = var.dns_realm
      username = data.vault_kv_secret_v2.windows_domain_admin.data["username"]
      password = data.vault_kv_secret_v2.windows_domain_admin.data["password"]
    }
  }
}

provider "flux" {
  kubernetes = {
    host                   = local.kubeconfig.clusters[0].cluster.server
    client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
  }
  git = {
    url = "https://github.com/richrobertson/homelab_flux.git"
    http = {
      username = "git" # This can be any string when using a personal access token
      password = data.vault_kv_secret_v2.github_token.data["token"]
    }
  }
}

provider "github" {
  owner = "richrobertson"
  token = data.vault_kv_secret_v2.github_token.data["token"]
}

provider "powerdns" {}

provider "microsoftadcs" {
  host     = var.adcs_host
  username = data.vault_kv_secret_v2.windows_domain_admin.data["username"]
  password = data.vault_kv_secret_v2.windows_domain_admin.data["password"]
  use_ntlm = true
}