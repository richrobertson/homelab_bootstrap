# Certificate Module
#
# Provisions TLS certificates and Vault PKI signing for a given DNS name.

# -----------------------------
# Local Variables
# Define organization for certificate subject.
# -----------------------------
# -----------------------------
# TLS Certificate Request Resource
# Generates a certificate signing request for the DNS name.
# -----------------------------
# -----------------------------
# Vault PKI Secret Backend Sign Resource
# Signs the certificate request using Vault PKI backend.
# -----------------------------
# -----------------------------
# Outputs
# Exposes private key and certificate as outputs.
# -----------------------------
variable "dns_name" {
  type = string
}

variable "private_key_pem" {
  description = "PEM-encoded private key used to build the certificate request."
  type        = string
  sensitive   = true
}

variable "vault_pki_backend" {
  description = "Vault PKI backend path used for certificate signing."
  type        = string
}

variable "vault_pki_role" {
  description = "Vault PKI role used for certificate issuance."
  type        = string
}

locals {
  organization = "myrobertson.net"
}

resource "tls_cert_request" "example" {
  private_key_pem = var.private_key_pem

  dns_names = [var.dns_name]

  subject {
    common_name  = var.dns_name
    organization = local.organization
  }
}

resource "vault_pki_secret_backend_sign" "test" {
  backend     = var.vault_pki_backend
  name        = var.vault_pki_role
  csr         = tls_cert_request.example.cert_request_pem
  common_name = var.dns_name
  
}

output "private_key_pem" {
  value     = var.private_key_pem
  sensitive = true
}

output "certificate_pem" {
  value = vault_pki_secret_backend_sign.test.certificate
}