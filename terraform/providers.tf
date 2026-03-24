

locals {
  kubeconfig = yamldecode(module.nodes.kubeconfig)
}

provider "dns" {
  update {
    server = "myrobertson.net"
    gssapi {
      realm    = "myrobertson.net"
      username = data.vault_generic_secret.windows_domain_admin.data["username"]
      password = data.vault_generic_secret.windows_domain_admin.data["password"]
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
      password = data.vault_generic_secret.github_token.data["token"]
    }
  }
}

provider "github" {
  owner = "richrobertson"
  token = data.vault_generic_secret.github_token.data["token"]
}

provider "powerdns" {}

provider "microsoftadcs" {
  host     = "dc1.myrobertson.net"
  username = data.vault_generic_secret.windows_domain_admin.data["username"]
  password = data.vault_generic_secret.windows_domain_admin.data["password"]
  use_ntlm = true
}