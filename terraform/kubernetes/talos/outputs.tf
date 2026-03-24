output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "kubernetes_client_configuration" {
  value     = talos_cluster_kubeconfig.this.kubernetes_client_configuration
  sensitive = true
}

output "cluster_endpoint" {
  value     = local.cluster_endpoint
  sensitive = false
}