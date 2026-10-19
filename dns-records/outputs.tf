output "records_by_key" {
  description = "Records as a map from key to an object with `name` (fully qualified, lower case, without the trailing dot), `type`, `ttl` and `values`. AAAA values are in canonical form"
  value = {
    for key, r in local.records : key => {
      name   = r.fqdn
      type   = r.type
      ttl    = r.ttl
      values = r.values
    }
  }
}

output "zone_id" {
  description = "Poweradmin ID of the zone"
  value       = tonumber(data.poweradmin_zone.this.id)
}
