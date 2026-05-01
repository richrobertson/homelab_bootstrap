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

data "vault_generic_secret" "root_ca_cert" {
  path = "secret/windows/domain/root_ca_cert"
}

data "vault_generic_secret" "vault_ca_cert" {
  path = "secret/substrate/vault_ca"
}

data "vault_generic_secret" "talos_secrets" {
  path = "secret/talos/${local.env.environment_name}"
}

data "vault_generic_secret" "volsync_s3_settings" {
  path = var.volsync_s3_settings_vault_path
}

data "vault_generic_secret" "email_canary_alerts" {
  count = var.enable_email_canary ? 1 : 0

  path = var.email_canary_alerts_vault_path
}
