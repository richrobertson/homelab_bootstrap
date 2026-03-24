output "subns_server" {
  value = module.powerdns_auth_server.host
}

output "nsr_server" {
  value = module.powerdns_recurse_server.host
}