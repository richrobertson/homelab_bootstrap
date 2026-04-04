variable "environment_name" {
  type = string
}

variable "vault_kubernetes_auth_backend" {
  type    = string
  default = ""
}

variable "vault_pki_secret_backend_path" {
  type    = string
  default = ""
}

variable "kubernetes_cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
  default     = ""
}

variable "vault_pki_policy_paths" {
  description = "List of Vault policy path configurations for PKI cert-issuer"
  type = list(object({
    path         = string
    capabilities = list(string)
  }))
  default = []
}
