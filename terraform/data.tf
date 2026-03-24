data "proxmox_virtual_environment_nodes" "available_nodes" {}

data "vault_kv_secret_v2" "proxmox_token" {
  mount = "secret"
  name  = "proxmox/cl0/terraform"
}

data "vault_kv_secret_v2" "github_token" {
  mount = "secret"
  name  = "github"
}

data "vault_kv_secret_v2" "windows_domain_admin" {
  mount = "secret"
  name  = "windows/domain/ldap"
}