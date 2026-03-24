
variable "role_name" {
  type = string
}

locals {
  role = local.roles[var.role_name]
}


resource "tls_private_key" "this" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "this" {
  private_key_pem = tls_private_key.this.private_key_pem
  subject {
    organization = local.role.organization == "" ? null : local.role.organization
    common_name  = var.role_name
  }
}

#https://registry.terraform.io/providers/flipyap/microsoft-adcs/latest/docs/resources/certificate
resource "microsoftadcs_certificate" "this" {
  certificate_signing_request = tls_cert_request.this.cert_request_pem
  template                    = "SubordinateCertificationAuthority-Vault"
}

output "private_key_pem" {
  value     = tls_private_key.this.private_key_pem
  sensitive = true
}

output "cert_pem" {
  value = chomp(microsoftadcs_certificate.this.certificate_pem)
}

output "cert_chain_pem" {
  value = <<-EOF
  ${microsoftadcs_certificate.this.certificate_pem}
  -----BEGIN CERTIFICATE-----
  MIICCDCCAa+gAwIBAgIQF9zxtm7FcrlB+hsJIdZ7mzAKBggqhkjOPQQDAjBRMRMw
  EQYKCZImiZPyLGQBGRYDbmV0MRswGQYKCZImiZPyLGQBGRYLbXlyb2JlcnRzb24x
  HTAbBgNVBAMTFG15cm9iZXJ0c29uLURDMS1DQS0xMB4XDTI1MTAyMDE3MjMxNFoX
  DTQwMTAyMDE3MzMwN1owUTETMBEGCgmSJomT8ixkARkWA25ldDEbMBkGCgmSJomT
  8ixkARkWC215cm9iZXJ0c29uMR0wGwYDVQQDExRteXJvYmVydHNvbi1EQzEtQ0Et
  MTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABK+4DJe8IQJfxAzy0rPHXzB90y6j
  VH8DIkZ7MVKDiU3I4wvijS377qYF29isRM7PAIJqoBn2qrj3tq0VXf2kVqejaTBn
  MBMGCSsGAQQBgjcUAgQGHgQAQwBBMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8E
  BTADAQH/MB0GA1UdDgQWBBRDeCmhtlyh4RyCRpNsWwmHhSQIiTAQBgkrBgEEAYI3
  FQEEAwIBADAKBggqhkjOPQQDAgNHADBEAiBanuCZDMRVikhd3L9npjlcU/RfYTM9
  KBEosp9OrdExBwIgMyq4owAejBTFfxDEco8n/Si9OBQLLZ01n+vwnwLr964=
  -----END CERTIFICATE-----
  EOF
}