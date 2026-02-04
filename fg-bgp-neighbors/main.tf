resource "fortios_routerbgp_neighbor" "this" {
  count = length(var.neighbors)

  ip                           = var.neighbors[count.index].ip
  remote_as                    = var.remote_as
  activate                     = "disable"
  activate6                    = "enable"
  soft_reconfiguration6        = "enable"
  capability_graceful_restart6 = "enable"
  description                  = "Cluster: ${var.cluster_name} Node: ${var.neighbors[count.index].name}"
  prefix_list_in6              = fortios_router_prefixlist6.in.name
  prefix_list_out6             = fortios_router_prefixlist6.out.name
}

resource "fortios_router_prefixlist6" "in" {
  name     = "${var.cluster_name}-in"
  comments = "Cluster: ${var.cluster_name} - Prefix list in"

  dynamic "rule" {
    for_each = var.prefixes
    content {
      id      = rule.key + 1
      action  = "permit"
      prefix6 = rule.value.prefix
      ge      = rule.value.ge
    }
  }
}

# Use default route
resource "fortios_router_prefixlist6" "out" {
  name     = "${var.cluster_name}-out"
  comments = "Cluster: ${var.cluster_name} - Prefix list out"

  rule {
    id      = 1
    action  = "deny"
    prefix6 = "any"
  }
}
