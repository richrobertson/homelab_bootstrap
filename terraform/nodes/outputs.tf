output "talosconfig" {
  value     = module.talos_cluster.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.talos_cluster.kubeconfig
  sensitive = true
}
