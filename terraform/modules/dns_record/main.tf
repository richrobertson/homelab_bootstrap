# DNS Record Module
#
# Provisions DNS records (A, AAAA, etc.) in a PowerDNS zone.

# -----------------------------
# PowerDNS Record Resource
# Creates DNS records in the specified zone.
# -----------------------------
variable "record" {
  type = object({
    zone_name = string
    name      = string
    type      = string
    records   = list(string)
  })
}

# Add A record to the zone
resource "powerdns_record" "records" {
  zone    = endswith(var.record.zone_name, ".") ? var.record.zone_name : "${var.record.zone_name}."
  name    = endswith(var.record.zone_name, ".") ? "${var.record.name}.${var.record.zone_name}" : "${var.record.name}.${var.record.zone_name}."
  type    = var.record.type
  ttl     = 300
  records = var.record.records
}
