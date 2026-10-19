variable "zone_name" {
  description = "Poweradmin zone the records are created in, such as `gathering.systems`. The zone must exist; the module looks it up by name"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9A-Za-z_-]+(\\.[0-9A-Za-z_-]+)*\\.?$", var.zone_name))
    error_message = "zone_name must be a DNS domain: labels of letters, digits, hyphens and underscores, separated by dots."
  }
}

variable "records_by_key" {
  description = <<-EOT
    Records as a map from a caller-chosen key to a record set:
    - `name`: fully qualified name inside `zone_name`, such as `api.k8s.gathering.systems`. A trailing dot is allowed. `zone_name` itself is the zone apex
    - `type`: record type, `AAAA` by default
    - `ttl`: TTL in seconds, `ttl` by default
    - `values`: the contents of the record set, at least one. An `AAAA` value must be an IPv6 address without a prefix length

    One key is one record set: give each name and type one key only.
  EOT
  type = map(object({
    name   = string
    type   = optional(string, "AAAA")
    ttl    = optional(number)
    values = list(string)
  }))
  nullable = false

  validation {
    condition     = alltrue([for r in values(var.records_by_key) : can(regex("^(\\*\\.)?[0-9A-Za-z_-]+(\\.[0-9A-Za-z_-]+)*\\.?$", r.name))])
    error_message = "Every name must be a DNS name: labels of letters, digits, hyphens and underscores, separated by dots, optionally starting with a wildcard label `*.`."
  }

  validation {
    condition     = alltrue([for r in values(var.records_by_key) : r.type != null && can(regex("^[A-Za-z][A-Za-z0-9]*$", r.type))])
    error_message = "Every type must be a DNS record type such as AAAA, CNAME or TXT."
  }

  validation {
    # Conditionals, not || and &&: OpenTofu 1.8 evaluates both sides
    condition     = alltrue([for r in values(var.records_by_key) : r.ttl == null ? true : r.ttl >= 1])
    error_message = "A TTL must be at least 1 second."
  }

  validation {
    condition     = alltrue([for r in values(var.records_by_key) : r.values == null ? false : length(r.values) > 0 && alltrue([for v in r.values : v == null ? false : v != ""])])
    error_message = "Every record needs at least one value, and no value may be empty."
  }

  validation {
    condition = alltrue([
      for r in values(var.records_by_key) : alltrue([
        for v in coalesce(r.values, []) : can(cidrhost("${v}/128", 0))
      ]) if upper(coalesce(r.type, "AAAA")) == "AAAA"
    ])
    error_message = "Every value of an AAAA record must be an IPv6 address without a prefix length."
  }
}

variable "ttl" {
  description = "TTL in seconds of a record that sets none"
  type        = number
  default     = 300
  nullable    = false

  validation {
    condition     = var.ttl >= 1
    error_message = "ttl must be at least 1 second."
  }
}
