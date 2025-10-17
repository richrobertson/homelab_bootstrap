

locals {
  vault_pki_role_name = "myrobertson-dot-net"
}

resource "vault_policy" "vault-cert-issuer-policy" {
  name = "${var.environment_name}-kubernetes-pki"

  policy = <<EOT

path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "auth/${var.environment_name}-kubernetes/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "${var.environment_name}-kubernetes/*" {
  capabilities = ["update", "read", "list", "create", "delete", "sudo"]
}
path "auth/${var.environment_name}-kubernetes/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "pki_int*"                        { capabilities = ["read", "list"] }
path "pki_int/sign/${local.vault_pki_role_name}"    { capabilities = ["create", "update"] }
path "pki_int/issue/${local.vault_pki_role_name}"   { capabilities = ["create"] }
path "pki_int/roles/${local.vault_pki_role_name}"   { capabilities = ["create","read", "list"] }
EOT
}


resource "vault_kubernetes_auth_backend_role" "vault-cert-issuer-role" {
  backend                          = var.vault_kubernetes_auth_backend
  role_name                        = "vault-cert-issuer-role"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = ["*"]
  token_policies                   = [vault_policy.vault-cert-issuer-policy.name, "default"]
  audience                         = var.kubernetes_cluster_endpoint
}