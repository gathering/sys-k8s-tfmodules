locals {
  # False for an empty control-plane pool too, which the precondition on the machine configuration rejects
  bootstrap = var.type == "controlplane" && length(var.node_keys) > 0

  # Position of a key in node_keys. Only decides the host a new VM is created on
  key_index = { for i, key in var.node_keys : key => i }

  # Node addresses without the prefix length, in node_keys order
  node_ips = [for key in var.node_keys : split("/", netbox_available_ip_address.this[key].ip_address)[0]]

  node_prefix_id = var.netbox_node_prefix_lookup ? tonumber(data.netbox_prefix.node[0].id) : var.netbox_node_prefix_id
  gateway        = var.gateway != null ? var.gateway : cidrhost(var.netbox_node_prefix, 1)
}
