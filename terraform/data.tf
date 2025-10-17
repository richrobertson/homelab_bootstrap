data "proxmox_virtual_environment_nodes" "available_nodes" {}

data "vault_generic_secret" "proxmox_token" {
  path = "secret/proxmox/cl0/terraform"
}

data "vault_generic_secret" "github_token" {
  path = "secret/github"
}

data "vault_generic_secret" "windows_domain_admin" {
  path = "secret/windows/domain/ldap"
}

data "vault_generic_secret" "substrate_db1" {
  path = "secret/substrate/db1"
}