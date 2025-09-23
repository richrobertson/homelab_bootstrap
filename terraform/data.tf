data "proxmox_virtual_environment_nodes" "available_nodes" {}

data "vault_generic_secret" "proxmox_token" {
  path = "secret/proxmox/cl0/terraform"
}