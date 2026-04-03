
resource "vault_kubernetes_secret_backend" "config" {
  path               = "${var.environment_name}-kubernetes"
  description        = "kubernetes secrets engine description"
  kubernetes_host    = var.kubernetes_cluster_endpoint
  kubernetes_ca_cert = var.kubernetes_cluster_ca_certificate
}

resource "vault_kubernetes_secret_backend_role" "vault-secrets-operator-role" {
  backend                       = vault_kubernetes_secret_backend.config.path
  name                          = "vault-secrets-operator-role"
  allowed_kubernetes_namespaces = var.allowed_kubernetes_namespaces
  service_account_name          = var.service_account_name
}

resource "vault_policy" "vault-secrets-operator-policy" {
  name = "${var.environment_name}-kubernetes"

  policy = <<EOT

path "${var.environment_name}-kubernetes/*" {
  capabilities = ["read", "list"]
}

path "secret/data/${var.allowed_secret_path_prefix}/*" {
  capabilities = ["read"]
}

path "secret/metadata/${var.allowed_secret_path_prefix}/*" {
  capabilities = ["list"]
}

EOT
}

resource "vault_kubernetes_auth_backend_role" "vault-secrets-operator-role" {
  backend                          = var.vault_kubernetes_auth_backend
  role_name                        = vault_kubernetes_secret_backend_role.vault-secrets-operator-role.name
  bound_service_account_names      = [var.service_account_name, "vault-secrets-operator-controller-manager"]
  bound_service_account_namespaces = var.allowed_kubernetes_namespaces
  token_policies                   = ["${var.environment_name}-kubernetes", "default"]
  audience                         = var.kubernetes_cluster_endpoint
}
