locals {
  # VIP name suffix => port, the same on the VIP and on the nodes
  vips = {
    k8s-api           = 6443
    talos-control-api = 50001
    talosctl-api      = 50000
  }

  # In id order
  realservers = values({
    for rs in values(var.realservers_by_key) : format("%010d", rs.id) => { id = rs.id, ip = rs.ip }
  })
}

resource "fortios_firewall_vip6" "this" {
  for_each = local.vips

  name        = "${var.cluster_name}-${each.key}"
  extip       = var.extip
  extport     = tostring(each.value)
  server_type = "tcp"
  ldb_method  = "static"
  mappedip    = "::"
  type        = "server-load-balance"

  monitor {
    name = var.monitor
  }

  dynamic "realservers" {
    for_each = local.realservers
    content {
      id   = realservers.value.id
      ip   = realservers.value.ip
      port = each.value
    }
  }
}

# Service ALL is enough: the VIPs only listen on their own port
module "policy" {
  source = "../fg-policy"

  name            = "${var.cluster_name}-api-in"
  srcintf         = var.srcintf
  srcaddr6        = var.srcaddr6
  dstintf         = var.dstintf
  dstaddr6        = [for vip in fortios_firewall_vip6.this : vip.name]
  services        = ["ALL"]
  ssl_ssh_profile = var.ssl_ssh_profile
  nat             = false
}
