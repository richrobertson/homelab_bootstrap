variable "github_org" {
  description = "GitHub organization"
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository"
  type        = string
  default     = ""
}

variable "kubernets_cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
  default     = ""
}

variable "kubernets_client_certificate" {
  description = "Kubernetes client certificate"
  type        = string
  default     = ""
}

variable "kubernets_client_key" {
  description = "Kubernetes client key"
  type        = string
  default     = ""
}

variable "kubernets_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "The name of the cluster (used for path in repo)"
  type        = string
  default     = "staging"
}



