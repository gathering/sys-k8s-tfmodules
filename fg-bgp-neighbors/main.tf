locals {
  prefix_list_name = coalesce(var.prefix_list_name, var.cluster_name)
}

resource "fortios_routerbgp_neighbor" "this" {
  for_each = var.neighbors_by_key

  ip                           = each.value.ip
  remote_as                    = var.remote_as
  activate                     = "disable"
  activate6                    = "enable"
  soft_reconfiguration6        = "enable"
  capability_graceful_restart6 = "enable"
  description                  = "Cluster: ${var.cluster_name} Node: ${each.value.name}"
  prefix_list_in6              = fortios_router_prefixlist6.in.name
  prefix_list_out6             = fortios_router_prefixlist6.out.name
}

resource "fortios_router_prefixlist6" "in" {
  name     = "${local.prefix_list_name}-in"
  comments = "Prefixes accepted from Kubernetes cluster ${var.cluster_name}. Managed by OpenTofu"

  dynamic "rule" {
    for_each = var.prefixes
    content {
      # Without an explicit id, the position in the list
      id      = coalesce(rule.value.id, rule.key + 1)
      action  = "permit"
      prefix6 = rule.value.prefix
      ge      = rule.value.ge
      le      = rule.value.le
    }
  }
}

# Advertise nothing to the cluster: the nodes reach everything through their default route
resource "fortios_router_prefixlist6" "out" {
  name     = "${local.prefix_list_name}-out"
  comments = "Nothing is advertised to Kubernetes cluster ${var.cluster_name}. Managed by OpenTofu"

  rule {
    id      = 1
    action  = "deny"
    prefix6 = "any"
  }
}
