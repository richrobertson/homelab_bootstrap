locals {
  default_intel_igpu_hostpci = [
    {
      device = "hostpci0"
      id     = "0000:00:02.0"
      pcie   = true
    }
  ]

  env = local.envs[terraform.workspace]

  envs = {
    "production" = {
      environment_name       = "prod"
      environment_short_name = "prod"
      kubernetes = {
        cluster_name = "prod"
      }
      vrf_vxlan             = 4050
      controlplane_vlan_tag = 1050
      dataplane_vlan_tag    = 2050
      vxlan_octet = {
        "controlplane" = 30
        "dataplane"    = 31
        "metallb"      = 32
      }

      kubernetes_nodes = {
        controlplane = {
          cpu_cores    = 8
          memory_in_gb = 8
        }
        dataplane = {
          cpu_cores    = 16
          memory_in_gb = 24
        }
      }
      gpu_worker_fault_domains  = ["fd-0"]
      gpu_talos_installer_image = "factory.talos.dev/installer/bf2113e1bea48d566f7d1e08eb780f832ccb56bbd7cf2f95769f7a04f9f2b184:v1.12.6"
      # Vault PKI policy - production matches current live cert-issuer-only paths
      vault_pki_policy_paths = [
        { path = "pki_int_prod", capabilities = ["read", "list"] },
        { path = "pki_int_prod/sign/cluster_ssl_certs", capabilities = ["create", "update"] },
        { path = "pki_int_prod/issue/cluster_ssl_certs", capabilities = ["create"] },
        { path = "pki_int_prod/roles/cluster_ssl_certs", capabilities = ["create", "read", "list"] },
      ]
      # Vault PKI role - production allows bare domains and subdomains
      vault_pki_role = {
        allow_any_name     = true
        allow_bare_domains = false
        allow_subdomains   = false
        allowed_domains    = []
      }
    }
    "staging" = {
      environment_name       = "staging"
      environment_short_name = "stg"
      kubernetes = {
        cluster_name = "staging"
      }
      vrf_vxlan = 4000

      controlplane_vlan_tag = 1000
      dataplane_vlan_tag    = 2000
      vxlan_octet = {
        "controlplane" = 20
        "dataplane"    = 21
        "metallb"      = 22
      }

      kubernetes_nodes = {
        controlplane = {
          cpu_cores    = 8
          memory_in_gb = 8
        }
        dataplane = {
          cpu_cores    = 12
          memory_in_gb = 20
        }
      }
      gpu_worker_fault_domains  = ["fd-0"]
      gpu_talos_installer_image = "factory.talos.dev/installer/bf2113e1bea48d566f7d1e08eb780f832ccb56bbd7cf2f95769f7a04f9f2b184:v1.12.6"
      # Vault PKI policy - staging uses tighter, cert-issuer-only paths
      vault_pki_policy_paths = [
        { path = "pki_int_staging", capabilities = ["read", "list"] },
        { path = "pki_int_staging/sign/cluster_ssl_certs", capabilities = ["create", "update"] },
        { path = "pki_int_staging/issue/cluster_ssl_certs", capabilities = ["create"] },
        { path = "pki_int_staging/roles/cluster_ssl_certs", capabilities = ["create", "read", "list"] },
      ]
      # Vault PKI role - staging tighter: no bare domains, explicit domain list
      vault_pki_role = {
        allow_any_name     = false
        allow_bare_domains = true
        allow_subdomains   = true
        allowed_domains    = ["staging.myrobertson.net", "myrobertson.net"]
      }
    }
    "default" = {
      environment_name       = "development"
      environment_short_name = "dev"
      kubernetes = {
        cluster_name = "development"
      }
      vrf_vxlan = 4010

      controlplane_vlan_tag = 1010
      dataplane_vlan_tag    = 2010
      vxlan_octet = {
        "controlplane" = 10
        "dataplane"    = 11
        "metallb"      = 12
      }

      kubernetes_nodes = {
        controlplane = {
          cpu_cores    = 8
          memory_in_gb = 8
        }
        dataplane = {
          cpu_cores    = 8
          memory_in_gb = 8
        }
      }
      gpu_worker_fault_domains  = []
      gpu_talos_installer_image = null
      # Vault PKI policy - default uses tighter, cert-issuer-only paths
      vault_pki_policy_paths = [
        { path = "pki_int", capabilities = ["read", "list"] },
        { path = "pki_int/sign/cluster_ssl_certs", capabilities = ["create", "update"] },
        { path = "pki_int/issue/cluster_ssl_certs", capabilities = ["create"] },
        { path = "pki_int/roles/cluster_ssl_certs", capabilities = ["create", "read", "list"] },
      ]
      # Vault PKI role - default tighter: no bare domains, explicit domain list
      vault_pki_role = {
        allow_any_name     = false
        allow_bare_domains = true
        allow_subdomains   = true
        allowed_domains    = ["myrobertson.net"]
      }
    }
  }
}
