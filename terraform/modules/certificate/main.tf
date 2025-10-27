variable "dns_name" {
  type = string
}

locals {
  organization = "myrobertson.net"
}

resource "tls_cert_request" "example" {
  private_key_pem = file("private_key.pem")

  dns_names = [var.dns_name]

  subject {
    common_name  = var.dns_name
    organization = local.organization
  }
}

resource "vault_pki_secret_backend_sign" "test" {
  depends_on = [vault_pki_secret_backend_role.admin]
  backend    = "/pki_int"
  name       = "myrobertson-dot-net"
  csr        = tls_cert_request.example.cert_request_pem
  common_name = var.dns_name
  
}

output "private_key_pem" {
  value = tls_cert_request.example.private_key_pem
}

output "certificate_pem" {
  value = vault_pki_secret_backend_sign.test.certificate
}