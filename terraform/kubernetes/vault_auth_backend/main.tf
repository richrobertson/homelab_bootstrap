

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "${var.environment_name}-kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_cluster_endpoint
  kubernetes_ca_cert     = var.kubernetes_cluster_ca_certificate
  disable_iss_validation = false
  disable_local_ca_jwt   = false
}
