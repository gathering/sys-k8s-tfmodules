locals {
  # Keyed pool: nodes are tracked by key in the `keyed` resources. Otherwise by position in `this`
  keyed      = var.node_keys != null
  node_keys  = local.keyed ? var.node_keys : []
  node_count = local.keyed ? 0 : var.nodes
  pool_size  = local.keyed ? length(local.node_keys) : local.node_count

  # False for an empty control-plane pool too, which the precondition on the machine configuration rejects
  bootstrap = var.type == "controlplane" && local.pool_size > 0

  # Position of a key in node_keys. Only decides the host a new VM is created on
  key_index = { for i, key in local.node_keys : key => i }

  # Both in pool order: node_keys order, or position
  node_names = local.keyed ? [for key in local.node_keys : "${var.node_prefix}${key}"] : netbox_virtual_machine.this[*].name
  # Node addresses without the prefix length
  node_ips = [
    for ip in local.keyed ? [for key in local.node_keys : netbox_available_ip_address.keyed[key].ip_address] : netbox_available_ip_address.this[*].ip_address :
    split("/", ip)[0]
  ]

  node_prefix_id = var.netbox_node_prefix_lookup ? tonumber(data.netbox_prefix.node[0].id) : var.netbox_node_prefix_id
  gateway        = var.gateway != null ? var.gateway : cidrhost(var.netbox_node_prefix, 1)
}

# Keyed pools are named after their keys instead
resource "random_id" "this" {
  count  = local.node_count
  prefix = var.node_prefix

  byte_length = 2
}
