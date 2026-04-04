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
  zone    = "${var.record.zone_name}."
  name    = "${var.record.name}.${var.record.zone_name}."
  # Provider canonicalizes record type casing; normalize input to avoid perpetual diffs.
  type    = upper(var.record.type)
  ttl     = 300
  records = sort(var.record.records)
}
