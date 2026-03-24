data "proxmox_virtual_environment_nodes" "available_nodes" {}

data "vault_generic_secret" "proxmox_token" {
  path = "secret/data/proxmox/cl0/terraform"
}

data "vault_generic_secret" "github_token" {
  path = "secret/data/github"
}

data "vault_generic_secret" "windows_domain_admin" {
  path = "secret/data/windows/domain/ldap"
}

data "vault_generic_secret" "substrate_db1" {
  path = "secret/data/substrate/db1"
}

data "vault_generic_secret" "root_ca_cert" {
  path = "secret/data/windows/domain/root_ca_cert"
}

data "vault_generic_secret" "vault_ca_cert" {
  path = "secret/data/substrate/vault_ca"
}

data "vault_generic_secret" "talos_secrets" {
  path = "secret/data/talos/${local.env.environment_name}"
}