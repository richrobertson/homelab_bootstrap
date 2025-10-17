locals {
  env  = local.envs[terraform.workspace]

  envs = {
    "production" = {
        environment_name = "production"
        environment_short_name = "prod"
        kubernetes = {
            cluster_name = "production"
        }
    }
    "staging" = {
        environment_name = "staging"
        environment_short_name = "stg"
        kubernetes = {
            cluster_name = "staging"
        }
    }
    "default" = {
        environment_name = "development"
        environment_short_name = "dev"
        kubernetes = {
            cluster_name = "development"
        }
    }      
  }
}