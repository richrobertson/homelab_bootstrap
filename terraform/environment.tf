locals {
  env  = local.envs[terraform.workspace]

  envs = {
    "production" = {
        environment_name = "production"
        environment_short_name = "prod"
        kubernetes = {
            cluster_name = "production"
        }
        vrf_vxlan = 4050
        controlplane_vlan_tag = 1050
        dataplane_vlan_tag = 2050
        vxlan_octet = {
            "controlplane" = 30
            "dataplane"    = 31
            "metallb"      = 32
        }
    }
    "staging" = {
        environment_name = "staging"
        environment_short_name = "stg"
        kubernetes = {
            cluster_name = "staging"
        }
        vrf_vxlan = 4000

        controlplane_vlan_tag = 1000
        dataplane_vlan_tag = 2000
        vxlan_octet = {
            "controlplane" = 20
            "dataplane"    = 21
            "metallb"      = 22
        }
    }
    "default" = {
        environment_name = "development"
        environment_short_name = "dev"
        kubernetes = {
            cluster_name = "development"
        }
        vrf_vxlan = 4010

        controlplane_vlan_tag = 1010
        dataplane_vlan_tag = 2010
        vxlan_octet = {
            "controlplane" = 10
            "dataplane"    = 11
            "metallb"      = 12
        }
    }      
  }
}