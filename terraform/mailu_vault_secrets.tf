locals {
  manage_mailu_app_secret           = local.env.environment_name == "prod" && var.mail_domain != null
  manage_mailu_edge_runtime_secrets = local.env.environment_name == "prod" && var.mail_domain != null && length(module.mail_edge) > 0
  manage_mailu_edge_secrets         = local.env.environment_name == "prod" && length(module.mail_edge) > 0

  mailu_public_hostname    = local.effective_mail_domain == null ? null : local.effective_mail_hostname
  mailu_initial_admin_user = local.effective_mail_domain == null ? null : "admin@${local.effective_mail_domain}"
  mailu_home_service_ip    = local.env.environment_name == "prod" ? local.effective_home_mailu_tunnel_ip : null

  mailu_values = local.manage_mailu_edge_runtime_secrets ? merge(
    local.effective_enable_ses ? {
      externalRelay = {
        host = "[${module.mail_edge[0].ses_smtp_endpoint}]:587"
      }
    } : {},
  ) : null

  mailu_values_yaml = local.mailu_values == null ? null : yamlencode(local.mailu_values)
}

check "prod_mailu_requires_ses_relay" {
  assert {
    condition     = local.env.environment_name != "prod" || !local.effective_mail_edge_enabled || local.effective_enable_ses
    error_message = "Production Mailu must use the SES relay. Keep enable_ses=true when mail_edge_enabled=true in prod."
  }
}

resource "random_password" "mailu_secret_key" {
  count = local.manage_mailu_app_secret ? 1 : 0

  length  = 64
  special = false
}

resource "random_password" "mailu_initial_account_password" {
  count = local.manage_mailu_app_secret ? 1 : 0

  length           = 32
  special          = true
  override_special = "_-@"
}

resource "random_password" "mailu_postgres_admin_password" {
  count = local.manage_mailu_app_secret ? 1 : 0

  length           = 32
  special          = true
  override_special = "_-@"
}

resource "random_password" "mailu_postgres_user_password" {
  count = local.manage_mailu_app_secret ? 1 : 0

  length           = 32
  special          = true
  override_special = "_-@"
}

resource "random_password" "mailu_postgres_replication_password" {
  count = local.manage_mailu_app_secret ? 1 : 0

  length           = 32
  special          = true
  override_special = "_-@"
}

resource "random_password" "mailu_roundcube_password" {
  count = local.manage_mailu_app_secret ? 1 : 0

  length           = 32
  special          = true
  override_special = "_-@"
}

resource "vault_kv_secret_v2" "mailu_app" {
  count = local.manage_mailu_app_secret ? 1 : 0

  mount = "secret"
  name  = "mailu/${local.env.environment_name}/app"

  data_json = jsonencode({
    "secret-key"               = random_password.mailu_secret_key[0].result
    "initial-account-password" = random_password.mailu_initial_account_password[0].result
    "postgres-password"        = random_password.mailu_postgres_admin_password[0].result
    "password"                 = random_password.mailu_postgres_user_password[0].result
    "replication-password"     = random_password.mailu_postgres_replication_password[0].result
    "roundcube-password"       = random_password.mailu_roundcube_password[0].result
  })
}

resource "vault_kv_secret_v2" "mailu_ses_relay" {
  count = local.manage_mailu_edge_runtime_secrets ? 1 : 0

  mount = "secret"
  name  = "mailu/${local.env.environment_name}/ses-relay"

  data_json = jsonencode({
    "relay-username" = module.mail_edge[0].ses_smtp_username
    "relay-password" = module.mail_edge[0].ses_smtp_password
  })
}

resource "vault_kv_secret_v2" "mailu_aws_observability" {
  count = local.manage_mailu_edge_secrets && local.effective_enable_ses ? 1 : 0

  mount = "secret"
  name  = "mailu/${local.env.environment_name}/aws-observability"

  data_json = jsonencode({
    "AWS_ACCESS_KEY_ID"     = module.mail_edge[0].grafana_cloudwatch_access_key_id
    "AWS_SECRET_ACCESS_KEY" = module.mail_edge[0].grafana_cloudwatch_secret_access_key
    "AWS_REGION"            = local.aws_region
    "AWS_DEFAULT_REGION"    = local.aws_region
  })
}

resource "vault_kv_secret_v2" "mailu_config" {
  count = local.manage_mailu_edge_runtime_secrets ? 1 : 0

  mount = "secret"
  name  = "mailu/${local.env.environment_name}/config"

  data_json = jsonencode({
    "values.yaml" = local.mailu_values_yaml
  })
}
