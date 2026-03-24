locals {
  workspace_env = terraform.workspace == "default" ? "production" : terraform.workspace
  env           = lookup(local.envs, local.workspace_env, local.envs["default"])

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
          cpu_cores    = 8
          memory_in_gb = 16
        }
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
    }
  }
}