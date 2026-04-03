locals {
  cluster_fqdn     = "cp.${var.cluster_name}.${var.root_domain}"
  cluster_endpoint = "https://${local.cluster_fqdn}:6443"
  environment_name = var.cluster_name == "development" ? "dev" : var.cluster_name
  //machine_secrets = yamlencode(var.talos_secrets_yaml)
  # Talos Kubernetes Bootstrap Module
  #
  # This file configures Talos machine and cluster settings for Kubernetes control plane and worker nodes.
  # It manages secrets, patches, and endpoint configuration for secure and reproducible cluster bootstrapping.
  machine_secrets      = module.secrets.machine_secrets
  client_configuration = module.secrets.client_configuration

  install_image_patch = var.talos_installer_image == null ? [] : [yamlencode({
    machine = {
      install = {
        image = var.talos_installer_image
      }
    }
  })]

  global_patches = [
    file("${path.module}/files/extraKernelArgs.yaml"),
    file("${path.module}/files/root-ca.yaml"),
    file("${path.module}/files/rotate-server-certificates.yaml"),
  ]
}

module "secrets" {
  source                        = "./secrets"
  cluster_name                  = var.cluster_name
  vault_pki_secret_backend_path = var.vault_pki_secret_backend_path
}


data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  # -----------------------------
  # Local Variables
  # Define cluster FQDN, endpoint, secrets, and configuration patches.
  # -----------------------------
  machine_secrets = local.machine_secrets
  config_patches = concat(local.global_patches, local.install_image_patch, [
    yamlencode({
      machine = {
        certSANs = concat(
          [local.cluster_fqdn],
          [for k, v in var.node_data.controlplanes : v.ip4_address]
        )
      }
    })],
    [file("${path.module}/files/taint-cp-nodes.yaml")]
  )
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = local.machine_secrets
  # -----------------------------
  # Secrets Module
  # Retrieves machine and client secrets from Vault for Talos configuration.
  # -----------------------------
  config_patches = concat(local.global_patches, local.install_image_patch, [
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
  endpoints            = [for k, v in var.node_data.controlplanes : v.ip4_address]
  nodes                = [for k, v in var.node_data.controlplanes : v.ip4_address]

  # -----------------------------
  # Talos Machine Configuration Data (Control Plane)
  # Generates Talos machine configuration for control plane nodes, including endpoint, secrets, and patches.
  # -----------------------------
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = module.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  for_each                    = var.node_data.controlplanes
  node                        = each.value.ip4_address
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      # -----------------------------
      # Talos Client Configuration
      # Generates client configuration for accessing the Talos cluster.
      # -----------------------------
      hostname     = each.value.hostname
      ip4_address  = each.value.ip4_address
      ip4_gateway  = "${join(".", slice(split(".", each.value.ip4_address), 0, 3))}.1"
      install_disk = each.value.install_disk
    }),
    templatefile("${path.module}/templates/cp-scheduling.yaml.tmpl", {
      environment_name = local.environment_name
      root_domain      = var.root_domain
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
      # -----------------------------
      # Talos Machine Configuration Apply (Control Plane)
      # Applies generated configuration to control plane nodes.
      # -----------------------------
      hostname     = each.value.hostname
      ip4_address  = each.value.ip4_address
      ip4_gateway  = "${join(".", slice(split(".", each.value.ip4_address), 0, 3))}.1"
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

  # -----------------------------
  # Talos Machine Configuration Data (Worker)
  # Generates Talos machine configuration for worker nodes, including endpoint, secrets, and patches.
  # -----------------------------
  depends_on = [time_sleep.wait_20_seconds]

  client_configuration = module.secrets.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : v.ip4_address][0]
}

data "talos_cluster_health" "health" {
  count                  = 1
  depends_on             = [talos_machine_bootstrap.this]
  client_configuration   = data.talos_client_configuration.this.client_configuration
  control_plane_nodes    = [for k, v in var.node_data.controlplanes : v.ip4_address]
  worker_nodes           = [for k, v in var.node_data.workers : v.ip4_address]
  endpoints              = [for k, v in var.node_data.controlplanes : v.ip4_address]
  skip_kubernetes_checks = true
}


resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = module.secrets.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : v.ip4_address][0]
}