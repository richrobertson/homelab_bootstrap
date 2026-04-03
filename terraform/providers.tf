

provider "dns" {
  update {
    server = var.dns_update_server
    gssapi {
      realm    = var.dns_realm
      username = data.vault_kv_secret_v2.windows_domain_admin.data["username"]
      password = data.vault_kv_secret_v2.windows_domain_admin.data["password"]
    }
  }
}

provider "powerdns" {}

provider "microsoftadcs" {
  host = var.adcs_host
  # Keep the exact username format stored in Vault (UPN or DOMAIN\user),
  # which matches the successful manual NTLM checks.
  username = data.vault_kv_secret_v2.windows_domain_admin.data["username"]
  password = data.vault_kv_secret_v2.windows_domain_admin.data["password"]
  use_ntlm = true
}

provider "flux" {
  kubernetes = {
    host                   = module.kubernetes-cluster[0].cluster_endpoint
    client_certificate     = base64decode(module.kubernetes-cluster[0].kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(module.kubernetes-cluster[0].kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(module.kubernetes-cluster[0].kubernetes_client_configuration.ca_certificate)
  }

  git = {
    url = "https://github.com/${var.github_repository}.git"
    http = {
      username = "git"
      password = data.vault_kv_secret_v2.github_token.data["token"]
    }
  }
}