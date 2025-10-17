output "talosconfig" {
  value     = length(module.kubernetes-cluster) == 0 ? "" : module.kubernetes-cluster[0].talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = length(module.kubernetes-cluster) == 0 ? "" : module.kubernetes-cluster[0].kubeconfig
  sensitive = true
}
