output "ipv4_addresses" {
  value = [for ipv4 in try(flatten(proxmox_virtual_environment_vm.vm.ipv4_addresses), []) : ipv4 if !startswith(ipv4, "169.254.") && !startswith(ipv4, "127")]
}

output "ipv6_addresses" {
  value = [for ipv6 in try(flatten(proxmox_virtual_environment_vm.vm.ipv6_addresses), []) : ipv6 if ipv6 != "::1"]
}

output "hostname" {
  value = var.name
}