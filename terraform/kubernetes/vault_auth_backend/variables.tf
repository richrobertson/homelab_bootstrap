variable "environment_name" {
  type = string
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