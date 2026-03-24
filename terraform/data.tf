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

data "vault_kv_secret_v2" "root_ca_cert" {
  mount = "secret"
  name  = "windows/domain/root_ca_cert"
}

data "vault_kv_secret_v2" "vault_ca_cert" {
  mount = "secret"
  name  = "substrate/vault_ca"
}

data "vault_kv_secret_v2" "talos_secrets" {
  mount = "secret"
  name  = "talos/${local.env.environment_name}"
}