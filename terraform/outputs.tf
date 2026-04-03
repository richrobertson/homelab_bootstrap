output "talosconfig" {
  value     = module.kubernetes-cluster[0].talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.kubernetes-cluster[0].kubeconfig
  sensitive = true
}
