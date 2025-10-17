

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
    host                   = length(module.kubernetes-cluster) == 0 ? "" : module.kubernetes-cluster[0].kubernetes_client_configuration.host
    client_certificate     = length(module.kubernetes-cluster) == 0 ? "" : base64decode(module.kubernetes-cluster[0].kubernetes_client_configuration.client_certificate)
    client_key             = length(module.kubernetes-cluster) == 0 ? "" : base64decode(module.kubernetes-cluster[0].kubernetes_client_configuration.client_key)
    cluster_ca_certificate = length(module.kubernetes-cluster) == 0 ? "" : base64decode(module.kubernetes-cluster[0].kubernetes_client_configuration.ca_certificate)
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

provider "proxmox" {
  endpoint = "https://cl0.myrobertson.net:8006/"
  username = data.vault_generic_secret.proxmox_token.data["username"]
  password = data.vault_generic_secret.proxmox_token.data["password"]
  ssh {
    agent = true
  }
  insecure = true
}

provider "talos" {}