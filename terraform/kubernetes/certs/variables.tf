variable "environment_name" {
  type = string
}

variable "vault_kubernetes_auth_backend" {
  type    = string
  default = ""
}

variable "vault_pki_secret_backend_path" {
  type = string
}

variable "kubernetes_cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
  default     = ""
}
