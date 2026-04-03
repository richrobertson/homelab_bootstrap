variable "cluster_name" {
  type = string
}

variable "organization" {
  description = "Organization name for certificate subject. Example: Example.net"
  type        = string
  default     = null
  nullable    = true
}

variable "root_domain" {
  description = "Root domain for certificate allowed_domains. Example: example.net"
  type        = string
  default     = "example.net"
}


locals {
  default_lease_ttl_years = 1
  max_lease_ttl_years     = 11
  organization            = coalesce(var.organization, var.root_domain)
  seconds_in_a_year       = 365 * 24 * 60 * 60
  seconds_in_an_hour      = 60 * 60
  vault_mount_path        = "pki_int_${var.cluster_name}"
}

resource "vault_mount" "intermediate" {
  path                      = local.vault_mount_path
  type                      = "pki"
  default_lease_ttl_seconds = local.default_lease_ttl_years * local.seconds_in_a_year
  max_lease_ttl_seconds     = local.max_lease_ttl_years * local.seconds_in_a_year
}

resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate_ca_csr" {
  depends_on            = [vault_mount.intermediate]
  backend               = vault_mount.intermediate.path
  type                  = "internal"
  common_name           = "${var.cluster_name} ${local.organization} Intermediate CA"
  add_basic_constraints = true
  key_type              = "ec"
  key_bits              = 256
}

#https://registry.terraform.io/providers/flipyap/microsoft-adcs/latest/docs/resources/certificate
resource "microsoftadcs_certificate" "intermediate_ca_cert" {
  certificate_signing_request = vault_pki_secret_backend_intermediate_cert_request.intermediate_ca_csr.csr
  template                    = "SubordinateCertificationAuthority-Vault"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate_ca_cert" {
  backend     = vault_mount.intermediate.path
  certificate = trimspace(
    can(base64decode(microsoftadcs_certificate.intermediate_ca_cert.certificate_b64))
    ? base64decode(microsoftadcs_certificate.intermediate_ca_cert.certificate_b64)
    : microsoftadcs_certificate.intermediate_ca_cert.certificate_b64
  )
}

# Name the issuer
resource "vault_pki_secret_backend_issuer" "this" {
  backend     = vault_mount.intermediate.path
  issuer_ref  = vault_pki_secret_backend_intermediate_set_signed.intermediate_ca_cert.imported_issuers[0]
  issuer_name = replace(vault_pki_secret_backend_intermediate_cert_request.intermediate_ca_csr.common_name, " ", "_")

}

resource "vault_pki_secret_backend_config_issuers" "intermediate_issuers" {
  backend = vault_mount.intermediate.path
  default = vault_pki_secret_backend_intermediate_set_signed.intermediate_ca_cert.imported_issuers[0]
}


resource "vault_pki_secret_backend_role" "role" {
  backend            = local.vault_mount_path
  name               = "cluster_ssl_certs"
  issuer_ref         = vault_pki_secret_backend_intermediate_set_signed.intermediate_ca_cert.imported_issuers[0]
  ttl                = 3600
  allow_ip_sans      = true
  key_type           = "ec"
  key_bits           = 256
  allowed_domains    = ["${var.cluster_name}.${var.root_domain}", var.root_domain]
  allow_subdomains   = true
  allow_bare_domains = true
  allow_any_name     = false
}

output "vault_mount_path" {
  value = vault_mount.intermediate.path
}

output "issuer_id" {
  value = vault_pki_secret_backend_intermediate_set_signed.intermediate_ca_cert.imported_issuers[0]
}




