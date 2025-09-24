output "talosconfig" {
  value     = module.talos_cluster.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.talos_cluster.kubeconfig
  sensitive = true
}

output "kubernetes_client_configuration" {
  value     = module.talos_cluster.kubernetes_client_configuration
  sensitive = true
}