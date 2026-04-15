variable "enable_talos_cluster_health_check" {
  description = "Whether to run Talos cluster health checks during plan/apply."
  type        = bool
  default     = true
}