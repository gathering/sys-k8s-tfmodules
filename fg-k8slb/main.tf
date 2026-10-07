locals {
  # VIP name suffix => port, the same on the VIP and on the nodes
  vips = {
    k8s-api           = 6443
    talos-control-api = 50001
    talosctl-api      = 50000
  }

  realserver_ips = var.realservers == null ? [] : sort(var.realservers)

  # In id order. Without ids, a realserver is numbered by its position in the sorted address list
  realservers = var.realservers_by_key != null ? values({
    for rs in values(var.realservers_by_key) : format("%010d", rs.id) => { id = rs.id, ip = rs.ip }
    }) : [
    for ip in toset(local.realserver_ips) : { id = index(local.realserver_ips, ip) + 1, ip = ip }
  ]
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

  lifecycle {
    precondition {
      condition     = (var.realservers == null) != (var.realservers_by_key == null)
      error_message = "Set exactly one of realservers and realservers_by_key."
    }
  }
}

moved {
  from = fortios_firewall_vip6.k8s_api
  to   = fortios_firewall_vip6.this["k8s-api"]
}

moved {
  from = fortios_firewall_vip6.talos_control_api
  to   = fortios_firewall_vip6.this["talos-control-api"]
}

moved {
  from = fortios_firewall_vip6.talosctl_api
  to   = fortios_firewall_vip6.this["talosctl-api"]
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

  # No comment, NAT off, NAT64 unset. Changing these updates the policy on deployed clusters
  comments = ""
  nat      = false
  nat64    = null
}

moved {
  from = fortios_firewall_policy.this
  to   = module.policy.fortios_firewall_policy.this
}
