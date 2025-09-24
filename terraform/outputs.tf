output "talosconfig" {
  value     = module.nodes
  sensitive = true
}

output "kubeconfig" {
  value     = module.nodes.kubeconfig
  sensitive = true
}
