variable "zone_name" {
  type = string
}

variable "primary_authoritative_nameserver" {
  type    = string
  default = "subns.myrobertson.net."
}

locals {
  zone_name                        = endswith(var.zone_name, ".") ? var.zone_name : "${var.zone_name}."
  primary_authoritative_nameserver = endswith(var.primary_authoritative_nameserver, ".") ? var.primary_authoritative_nameserver : "${var.primary_authoritative_nameserver}."
}

resource "powerdns_zone" "zone" {
  name         = local.zone_name
  kind         = "Native"
  nameservers  = [local.primary_authoritative_nameserver]
  soa_edit_api = "INCEPTION-INCREMENT"
}
