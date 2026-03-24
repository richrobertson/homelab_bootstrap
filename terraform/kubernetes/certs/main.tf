

locals {
  vault_pki_role_name  = "cluster_ssl_certs"
  vault_pki_mount_path = trim(var.vault_pki_secret_backend_path, "/")
}

resource "vault_policy" "vault_cert_issuer_policy" {
  name = "${var.environment_name}-kubernetes-pki"

  policy = <<EOT

path "${local.vault_pki_mount_path}" { capabilities = ["read", "list"] }
path "${local.vault_pki_mount_path}/sign/${local.vault_pki_role_name}" { capabilities = ["create", "update"] }
path "${local.vault_pki_mount_path}/issue/${local.vault_pki_role_name}" { capabilities = ["create"] }
path "${local.vault_pki_mount_path}/roles/${local.vault_pki_role_name}" { capabilities = ["create", "read", "list"] }
EOT
}


resource "vault_kubernetes_auth_backend_role" "vault_cert_issuer_role" {
  backend                          = var.vault_kubernetes_auth_backend
  role_name                        = "vault-cert-issuer-role"
  bound_service_account_names      = ["cert-manager"]
  bound_service_account_namespaces = ["cert-manager"]
  token_policies                   = [vault_policy.vault_cert_issuer_policy.name, "default"]
  audience                         = var.kubernetes_cluster_endpoint
}