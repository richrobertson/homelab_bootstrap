output "ipv4_addresses" {
  value = [for ipv4 in flatten([for ip in proxmox_virtual_environment_vm.vm.ipv4_addresses : ip]) : ipv4 if !startswith(ipv4, "10.244") && !startswith(ipv4, "127") && !startswith(ipv4, "169")]
}

output "ipv6_addresses" {
  value = [for ipv6 in flatten([for ip in proxmox_virtual_environment_vm.vm.ipv6_addresses : ip]) : ipv6 if ipv6 != "::1"]
}

output "hostname" {
  value = var.name
}