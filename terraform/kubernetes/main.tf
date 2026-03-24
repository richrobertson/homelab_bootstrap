# Kubernetes Module
#
# Deploys Kubernetes nodes, control plane, and related resources. Integrates with Vault and Talos for secrets and cluster bootstrapping.

# -----------------------------
# Nodes Module
# Provisions Kubernetes control plane and worker nodes as VMs.
# -----------------------------
# -----------------------------
# Vault PKI Secret Backend Module
# Sets up Vault PKI backend for Kubernetes cluster certificates.
# -----------------------------
# -----------------------------
# Talos Cluster Module
# Bootstraps Talos-based Kubernetes cluster, generating configs and secrets.
# -----------------------------
# -----------------------------
# Vault Auth Backend Module
# Configures Vault Kubernetes authentication backend.
# -----------------------------
# -----------------------------
# Vault Secret Backend Module
# Configures Vault secret backend for Kubernetes.
# -----------------------------
# -----------------------------
# Certs Module
# Provisions certificates for Kubernetes cluster.
# -----------------------------


module "nodes" {
  source        = "./nodes"
  fault_domains = var.fault_domains

  cluster_short_name = var.environment_short_name
  proxmox_ve_nodes   = var.proxmox_ve_nodes
  dns_auth_server    = var.dns_auth_server
  dns = {
    domain = "${var.environment_name}.myrobertson.net"
    servers = {
      ipv4_addresses = var.dns_server.ipv4_addresses
      ipv6_addresses = var.dns_server.ipv6_addresses
    }
  }

  control_plane_network_bridge = var.control_plane_network_bridge
  control_plane_cpu_cores      = var.kubernetes_nodes_resources["controlplane"].cpu_cores
  control_plane_memory_in_gb   = var.kubernetes_nodes_resources["controlplane"].memory_in_gb
  control_plane_subnets_by_fd  = var.control_plane_subnets_by_fd

  worker_cpu_cores      = var.kubernetes_nodes_resources["dataplane"].cpu_cores
  worker_memory_in_gb   = var.kubernetes_nodes_resources["dataplane"].memory_in_gb
  worker_network_bridge = var.worker_network_bridge
  worker_subnets_by_fd  = var.worker_subnets_by_fd
}

module "vault_pki_secret_backend" {
  source       = "./vault_pki_secret_backend"
  cluster_name = var.cluster_name
}

module "talos_cluster" {
  depends_on   = [module.nodes]
  source       = "./talos"
  cluster_name = var.cluster_name
  node_data = {
    controlplanes = {
      for k, v in var.fault_domains :
      k => {
        ip4_address  = "${cidrhost(var.control_plane_subnets_by_fd[k].cidr, 2)}"
        install_disk = "/dev/vda"
        #hostname     = "k8s-${var.environment_short_name}-cp-${v.id}.cp.${k}.${local.dns.domain}"
        hostname = "k8s-${var.environment_short_name}-cp-${v.id}"
      }
    }
    workers = {
      for k, v in var.fault_domains :
      k => {
        ip4_address  = "${cidrhost(var.worker_subnets_by_fd[k].cidr, 2)}"
        install_disk = "/dev/vda"
        #hostname     = "k8s-${var.environment_short_name}-worker-${v.id}.dp.${k}.${local.dns.domain}" 
        hostname = "k8s-${var.environment_short_name}-worker-${v.id}"
      }
    }
  }
  vault_pki_secret_backend_path = module.vault_pki_secret_backend.vault_mount_path
}


module "vault_auth_backend" {
  source     = "./vault_auth_backend"
  depends_on = [module.talos_cluster]

  environment_name                  = var.environment_name
  kubernetes_cluster_ca_certificate = base64decode(module.talos_cluster.kubernetes_client_configuration.ca_certificate)
  kubernetes_cluster_endpoint       = module.talos_cluster.cluster_endpoint
}

module "vault_secret_backend" {
  source     = "./vault_secret_backend"
  depends_on = [module.vault_auth_backend]

  environment_name                  = var.environment_name
  kubernetes_cluster_ca_certificate = base64decode(module.talos_cluster.kubernetes_client_configuration.ca_certificate)
  kubernetes_cluster_endpoint       = module.talos_cluster.cluster_endpoint
  vault_kubernetes_auth_backend     = module.vault_auth_backend.backend
}

module "certs" {
  source = "./certs"

  environment_name              = var.environment_name
  kubernetes_cluster_endpoint   = module.talos_cluster.cluster_endpoint
  vault_kubernetes_auth_backend = module.vault_auth_backend.backend
  vault_pki_secret_backend_path = module.vault_pki_secret_backend.vault_mount_path
}



