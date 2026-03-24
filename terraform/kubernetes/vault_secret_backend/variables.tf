variable "environment_name" {
  type = string
}

variable "vault_kubernetes_auth_backend" {
  type    = string
  default = ""
}

variable "kubernetes_cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
  default     = ""
}

variable "kubernetes_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  type        = string
  default     = ""
}

variable "service_account_name" {
  type    = string
  default = "default"
}

variable "allowed_kubernetes_namespaces" {
  description = "Namespaces allowed to use the generated Vault Kubernetes role."
  type        = list(string)
  default     = ["vault-secrets-operator-system"]
}

variable "allowed_secret_path_prefix" {
  description = "Prefix under secret/data that the policy can access."
  type        = string
  default     = "platform"
}