
locals {
  cluster_short_name = terraform.workspace == "default" ? "production" : "${terraform.workspace}"
}

module "nodes" {
  source = "./nodes"

  cluster_short_name      = local.cluster_short_name
  proxmox_ve_nodes        = data.proxmox_virtual_environment_nodes.available_nodes.names
  network_bridge          = "vmbr1"
  network_vlan_id         = 20
  control_plane_cpu_cores = 16
  control_plane_memory_in_gb = 10
  control_plane_count = 5

  worker_count = 3
  worker_cpu_cores = 12
  worker_memory_in_gb = 20

}

provider "flux" {
  kubernetes = {
    host                   = module.nodes.kubernetes_client_configuration.host
    client_certificate     = base64decode(module.nodes.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(module.nodes.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(module.nodes.kubernetes_client_configuration.ca_certificate)
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

module "flux" {
  source = "./flux"
  depends_on = [module.nodes]
  github_org = "richrobertson"
  github_repository = "homelab_flux"
  kubernets_cluster_endpoint = module.nodes.kubernetes_client_configuration.host
  kubernets_client_certificate = base64decode(module.nodes.kubernetes_client_configuration.client_certificate)
  kubernets_client_key = base64decode(module.nodes.kubernetes_client_configuration.client_key)
  kubernets_cluster_ca_certificate = base64decode(module.nodes.kubernetes_client_configuration.ca_certificate)
  github_token = data.vault_generic_secret.github_token.data["token"]
  cluster_name = local.cluster_short_name

  providers = {
    flux = flux
    github = github
  }
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "${local.cluster_short_name}-kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = module.nodes.kubernetes_client_configuration.host
  kubernetes_ca_cert     = base64decode(module.nodes.kubernetes_client_configuration.ca_certificate)
  disable_iss_validation = "true"
  disable_local_ca_jwt  = "false"
  issuer = module.nodes.cluster_endpoint
}

 resource "vault_kubernetes_auth_backend_role" "vault-secrets-operator-role" {
  backend            = vault_kubernetes_auth_backend_config.this.backend
  role_name          = "vault-secrets-operator-role"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces  = ["*"]
  token_policies = [ vault_policy.vault-secrets-operator-policy.name, "default" ]
  audience = module.nodes.cluster_endpoint
}

resource "vault_policy" "vault-secrets-operator-policy" {
  name = "${local.cluster_short_name}-kubernetes"

  policy = <<EOT

path "auth/${local.cluster_short_name}-kubernetes/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "${local.cluster_short_name}-kubernetes/*" {
  capabilities = ["update", "read", "list", "create", "delete", "sudo"]
}

path "secret/data/synology/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "secret/data/proxmox/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}


resource "vault_kubernetes_secret_backend" "config" {
  path                      = "${local.cluster_short_name}-kubernetes"
  description               = "kubernetes secrets engine description"
  kubernetes_host           = module.nodes.kubernetes_client_configuration.host
  kubernetes_ca_cert        = base64decode(module.nodes.kubernetes_client_configuration.ca_certificate)
}

resource "vault_kubernetes_secret_backend_role" "vault-secrets-operator-role" {
  backend                       = vault_kubernetes_secret_backend.config.path
  name                          = "vault-secrets-operator-role"
  allowed_kubernetes_namespaces = ["*"]
  service_account_name          = "default"
} 

module firewall {
  source = "./firewall"
  fw_count = 0
  cluster_short_name = local.cluster_short_name
  proxmox_ve_nodes   = data.proxmox_virtual_environment_nodes.available_nodes.names
  memory_in_gb = 8
  lan_network_bridge = "dmz"
  wan_network_bridge = "vmbr1"
  wan_network_vlan_tag = 7
}