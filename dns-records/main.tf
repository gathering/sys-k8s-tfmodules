locals {
  zone = lower(trimsuffix(var.zone_name, "."))

  records = {
    for key, r in var.records_by_key : key => {
      fqdn = lower(trimsuffix(r.name, "."))
      type = upper(r.type)
      ttl  = coalesce(r.ttl, var.ttl)
      # Poweradmin keeps the address as given: write it the canonical way so that the same
      # address never shows as a change
      values = upper(r.type) == "AAAA" ? [for v in r.values : cidrhost("${v}/128", 0)] : r.values
    }
  }

  # Poweradmin takes the name relative to the zone, @ for the apex. Null for a name outside
  # the zone, refused by the precondition below
  relative_names = {
    for key, r in local.records : key => (
      r.fqdn == local.zone ? "@" : (endswith(r.fqdn, ".${local.zone}") ? trimsuffix(r.fqdn, ".${local.zone}") : null)
    )
  }

  name_types = [for r in values(local.records) : "${r.fqdn} ${r.type}"]
}

data "poweradmin_zone" "this" {
  name = local.zone
}

resource "poweradmin_rrset" "this" {
  for_each = local.records

  zone_id = tonumber(data.poweradmin_zone.this.id)
  name    = coalesce(local.relative_names[each.key], "@")
  type    = each.value.type
  ttl     = each.value.ttl

  records = [for v in each.value.values : { content = v, disabled = false, priority = 0 }]

  # Checked here because a variable validation cannot refer to a second variable in OpenTofu 1.8
  lifecycle {
    precondition {
      condition     = local.relative_names[each.key] != null
      error_message = "The name ${each.value.fqdn} is not in the zone ${local.zone}: give a name that ends in .${local.zone}, or the zone itself."
    }

    # Poweradmin replaces a record set on every write, so two keys for one name and type
    # would overwrite each other on each apply
    precondition {
      condition     = length(distinct(local.name_types)) == length(local.name_types)
      error_message = "Two keys of records_by_key have the same name and type. Give each name and type one key, with all its values."
    }
  }
}
