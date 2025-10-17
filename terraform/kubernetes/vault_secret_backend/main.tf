
resource "vault_kubernetes_secret_backend" "config" {
  path               = "${var.environment_name}-kubernetes"
  description        = "kubernetes secrets engine description"
  kubernetes_host    = var.kubernetes_cluster_endpoint
  kubernetes_ca_cert = var.kubernetes_cluster_ca_certificate
}

resource "vault_kubernetes_secret_backend_role" "vault-secrets-operator-role" {
  backend                       = vault_kubernetes_secret_backend.config.path
  name                          = "vault-secrets-operator-role"
  allowed_kubernetes_namespaces = ["*"]
  service_account_name          = var.service_account_name
}

resource "vault_policy" "vault-secrets-operator-policy" {
  name = "${var.environment_name}-kubernetes"

  policy = <<EOT

path "auth/${var.environment_name}-kubernetes/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "${var.environment_name}-kubernetes/*" {
  capabilities = ["update", "read", "list", "create", "delete", "sudo"]
}

path "secret/data/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

EOT
}

resource "vault_kubernetes_auth_backend_role" "vault-secrets-operator-role" {
  backend                          = var.vault_kubernetes_auth_backend
  role_name                        = vault_kubernetes_secret_backend_role.vault-secrets-operator-role.name
  bound_service_account_names      = [var.service_account_name, "vault-secrets-operator-controller-manager"]
  bound_service_account_namespaces = ["*"]
  token_policies                   = [vault_policy.vault-secrets-operator-policy.name, "default"]
  audience                         = var.kubernetes_cluster_endpoint
}
