locals {
  cluster_fqdn = "cp.${var.cluster_name}.myrobertson.net"
  cluster_endpoint      = "https://${local.cluster_fqdn}:6443"
  //machine_secrets = yamlencode(var.talos_secrets_yaml)
  machine_secrets = module.secrets.machine_secrets
  client_configuration = module.secrets.client_configuration


  global_patches = [
    file("${path.module}/files/extraKernelArgs.yaml"),
    file("${path.module}/files/root-ca.yaml"),
    file("${path.module}/files/rotate-server-certificates.yaml"),
  ]
}

module "secrets" {
  source = "./secrets"
  cluster_name = var.cluster_name
  vault_pki_secret_backend_path = var.vault_pki_secret_backend_path
}


data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = local.machine_secrets
  config_patches = concat(local.global_patches, [
    yamlencode({ 
      machine = { 
        certSANs = concat(
          [local.cluster_fqdn],
          [for k, v in var.node_data.controlplanes : v.ip4_address]
        )
      }
    }) ],
    [ file("${path.module}/files/taint-cp-nodes.yaml") ]
  )
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = local.machine_secrets
  config_patches = concat(local.global_patches, [
    yamlencode({ 
      machine = { 
        certSANs = concat(
          [local.cluster_fqdn],
          [for k, v in var.node_data.controlplanes : v.ip4_address]
        )
      }
    })
  ])
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = module.secrets.client_configuration
  endpoints            = [local.cluster_endpoint]
  nodes                = [for k, v in var.node_data.controlplanes : v.ip4_address]
  
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = module.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  for_each                    = var.node_data.controlplanes
  node                        = each.value.ip4_address
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = each.value.hostname
      install_disk = each.value.install_disk
    }),
    templatefile("${path.module}/templates/cp-scheduling.yaml.tmpl", {
      environment_name     = var.cluster_name
    }),
    file("${path.module}/files/metrics-server.yaml"),
    file("${path.module}/files/rotate-server-certificates.yaml"),
  ]
  timeouts = {
    create = "30s"
    delete = "30s"
    update = "30s"
  }
}

resource "talos_machine_configuration_apply" "worker" {
  depends_on                  = [talos_machine_configuration_apply.controlplane]
  client_configuration        = module.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  for_each                    = var.node_data.workers
  node                        = each.value.ip4_address
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = each.value.hostname
      install_disk = each.value.install_disk
    })
  ]
  timeouts = {
    create = "30s"
    delete = "30s"
    update = "30s"
  }
}


resource "time_sleep" "wait_20_seconds" {
  depends_on      = [talos_machine_configuration_apply.worker, talos_machine_configuration_apply.controlplane]
  create_duration = "20s"
}


resource "talos_machine_bootstrap" "this" {

  depends_on = [ time_sleep.wait_20_seconds ]

  client_configuration = module.secrets.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : v.ip4_address][0]
}

data "talos_cluster_health" "health" {
  count=1
  depends_on           = [ talos_machine_bootstrap.this ]
  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [for k, v in var.node_data.controlplanes : v.ip4_address]
  worker_nodes = [for k, v in var.node_data.workers : v.ip4_address]
  endpoints            = [for k, v in var.node_data.controlplanes : v.ip4_address]
  skip_kubernetes_checks = true
}


resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = module.secrets.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : v.ip4_address][0]
}