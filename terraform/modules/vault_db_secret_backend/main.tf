
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">=5.3.0"
    }
  }
}

ephemeral "vault_kv_secret_v2" "db_secret" {
  mount = "secret"
  name  = var.db_secret_name
}

# Enable database secrets engine
resource "vault_mount" "db" {
  path = "postgres"
  type = "database"
}

# Configure a secure Postgres connection using ephemeral resource and write-only attributes
resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.db.path
  name          = var.db_connection_name
  allowed_roles = ["pgx-role"]

  postgresql {
    connection_url      = "host=${var.db_host_ip_address} port=5432 user={{username}} password={{password}} dbname=postgres"
    username            = "postgres"
    password_wo         = tostring(ephemeral.vault_kv_secret_v2.db_secret.data.password)
    password_wo_version = 1
  }
}

# Create a role to generate Postgres DB credentials
resource "vault_database_secret_backend_role" "role" {
  backend = vault_mount.db.path
  name    = "pgx-role"
  db_name = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]
}

# Securely obtain database credentials using ephemeral resource
# ephemeral "vault_database_secret" "db_user_credentials" {
#   depends_on = [ vault_database_secret_backend_connection.postgres, vault_database_secret_backend_role.role ]
#   mount = vault_mount.db.path
#   name = vault_database_secret_backend_role.role.name
#   mount_id = vault_mount.db.id
# }