terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

resource "random_string" "token_prefix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "token_suffix" {
  length  = 16
  special = false
  upper   = false
}

output "bootstrap_token" {
  value     = "${random_string.token_prefix.result}.${random_string.token_suffix.result}"
  sensitive = true
}