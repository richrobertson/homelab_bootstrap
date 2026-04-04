

locals {
  vault_pki_backend_path = trimprefix(var.vault_pki_secret_backend_path, "/")
  vault_pki_role_name    = "cluster_ssl_certs"

  # Canonicalize rule order and capability order for stable policy text output.
  policy_path_keys = sort(keys({ for p in var.vault_pki_policy_paths : p.path => p }))

  policy_rules = [
    for policy_path in local.policy_path_keys :
    "path \"${policy_path}\" { capabilities = [${join(", ", [for cap in sort(distinct(lookup({ for p in var.vault_pki_policy_paths : p.path => p.capabilities }, policy_path, []))) : "\"${cap}\""])}] }"
  ]

  # Ensure a single trailing newline to match provider-normalized policy content.
  policy_content = length(local.policy_rules) > 0 ? "${join("\n", local.policy_rules)}\n" : ""
}

resource "vault_policy" "vault-cert-issuer-policy" {
  name = "${var.environment_name}-kubernetes-pki"

  policy = length(var.vault_pki_policy_paths) > 0 ? local.policy_content : <<EOT
path "${local.vault_pki_backend_path}" { capabilities = ["read", "list"] }
path "${local.vault_pki_backend_path}/sign/${local.vault_pki_role_name}" { capabilities = ["create", "update"] }
path "${local.vault_pki_backend_path}/issue/${local.vault_pki_role_name}" { capabilities = ["create"] }
path "${local.vault_pki_backend_path}/roles/${local.vault_pki_role_name}" { capabilities = ["create", "read", "list"] }
EOT
}


resource "vault_kubernetes_auth_backend_role" "vault-cert-issuer-role" {
  backend                          = var.vault_kubernetes_auth_backend
  role_name                        = "vault-cert-issuer-role"
  bound_service_account_names      = ["cert-manager", "default"]
  bound_service_account_namespaces = ["*"]
  token_policies                   = [vault_policy.vault-cert-issuer-policy.name, "default"]
  audience                         = var.kubernetes_cluster_endpoint
}