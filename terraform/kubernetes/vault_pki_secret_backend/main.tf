locals {
  default_lease_ttl_years = 1
  max_lease_ttl_years     = 11
  seconds_in_a_year       = 365 * 24 * 60 * 60
  seconds_in_an_hour      = 60 * 60
  vault_mount_path        = "/pki_int_${var.cluster_name}"
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
  common_name           = "${var.cluster_name} MyRobertson.net Intermediate CA"
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
  certificate = microsoftadcs_certificate.intermediate_ca_cert.certificate_b64

  # TEMPORARY DEFERRAL SWITCH:
  # Keep the currently imported Vault intermediate cert stable (no replace churn) until a planned PKI rotation window.
  # Remove this lifecycle block when you are ready to import/rotate the new intermediate cert.
  lifecycle {
    ignore_changes = [
      certificate,
    ]
  }
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
  backend            = trimprefix(vault_mount.intermediate.path, "/")
  name               = "cluster_ssl_certs"
  issuer_ref         = vault_pki_secret_backend_intermediate_set_signed.intermediate_ca_cert.imported_issuers[0]
  ttl                = 3600
  allow_any_name     = var.vault_pki_role.allow_any_name
  allow_bare_domains = var.vault_pki_role.allow_bare_domains
  allow_ip_sans      = true
  allow_subdomains   = var.vault_pki_role.allow_subdomains
  require_cn         = false
  # Only set allowed_domains if: 1) explicitly provided in config, or 2) allow_any_name is false
  allowed_domains = (
    length(var.vault_pki_role.allowed_domains) > 0
    ? var.vault_pki_role.allowed_domains
    : (var.vault_pki_role.allow_any_name ? [] : ["${var.cluster_name}.myrobertson.net", "myrobertson.net"])
  )
  key_type = "ec"
  key_bits = 256
}

output "vault_mount_path" {
  value = vault_mount.intermediate.path
}

output "issuer_id" {
  value = vault_pki_secret_backend_intermediate_set_signed.intermediate_ca_cert.imported_issuers[0]
}



