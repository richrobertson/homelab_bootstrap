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