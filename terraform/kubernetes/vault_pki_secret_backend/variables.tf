variable "cluster_name" {
  type = string
}

variable "vault_pki_role" {
  description = "Vault PKI role configuration for certificate generation"
  type = object({
    allow_any_name     = bool
    allow_bare_domains = bool
    allow_subdomains   = bool
    allowed_domains    = list(string)
  })
  default = {
    allow_any_name     = false
    allow_bare_domains = true
    allow_subdomains   = true
    allowed_domains    = ["myrobertson.net"]
  }
}
