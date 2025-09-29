locals {
  cluster_endpoint = "https://${var.control_plane_virtual_ip}:6443"
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in var.node_data.controlplanes : k]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  for_each                    = var.node_data.controlplanes
  node                        = each.key
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = each.value.hostname == null ? format("%s-cp-%s", var.cluster_name, index(keys(var.node_data.controlplanes), each.key)) : each.value.hostname
      install_disk = each.value.install_disk
    }),
    templatefile("${path.module}/templates/virtual_ip.yaml.tmpl", {
      virtual_ip   = var.control_plane_virtual_ip
    }),
    file("${path.module}/files/cp-scheduling.yaml"),
    file("${path.module}/files/metrics-server.yaml"),
    file("${path.module}/files/rotate-server-certificates.yaml"),
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  for_each                    = var.node_data.workers
  node                        = each.key
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = each.value.hostname == null ? format("%s-worker-%s", var.cluster_name, index(keys(var.node_data.workers), each.key)) : each.value.hostname
      install_disk = each.value.install_disk
    }),
    file("${path.module}/files/rotate-server-certificates.yaml"),
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : k][0]
}

data "talos_cluster_health" "health" {
  depends_on           = [ talos_machine_configuration_apply.controlplane, talos_machine_configuration_apply.worker ]
  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [for k, v in var.node_data.controlplanes : k]
  worker_nodes         = [for k, v in var.node_data.workers : k]
  endpoints            = data.talos_client_configuration.this.endpoints
}


resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this, data.talos_cluster_health.health]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : k][0]
}