variable "db_secret_name" {
  type    = string
  default = "substrate/db1"
}

variable "db_connection_name" {
  type    = string
  default = "postgres-db"
}

variable "db_host_ip_address" {
  type = string
}