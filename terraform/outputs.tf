output "talosconfig" {
  value     = module.nodes.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.nodes.kubeconfig
  sensitive = true
}
