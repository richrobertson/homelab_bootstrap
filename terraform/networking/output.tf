output "controlplane_subnets" {
  value = proxmox_virtual_environment_sdn_subnet.controlplane_subnets
}

output "dataplane_subnets" {
  value = proxmox_virtual_environment_sdn_subnet.dataplane_subnets
}

output "controlplane_network" {
  value = {
    bridge_name = proxmox_virtual_environment_sdn_vnet.controlplane.id
    vlan_id     = proxmox_virtual_environment_sdn_vnet.controlplane.tag
    subnets_by_fd = { for k, v in var.fault_domains : k => {
      cidr = proxmox_virtual_environment_sdn_subnet.controlplane_subnets[k].cidr
      }
    }
  }
}


output "dataplane_network" {
  value = {
    bridge_name = proxmox_virtual_environment_sdn_vnet.dataplane.id
    vlan_id     = proxmox_virtual_environment_sdn_vnet.dataplane.tag
    subnets_by_fd = { for k, v in var.fault_domains : k => {
      cidr = proxmox_virtual_environment_sdn_subnet.dataplane_subnets[k].cidr
      }
    }
  }
}