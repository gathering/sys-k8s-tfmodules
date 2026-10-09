data "netbox_cluster" "this" {
  name = var.netbox_cluster_name
}

data "netbox_device_role" "this" {
  name = var.netbox_device_role_name
}

# A separate switch, not a null check on the id: the id is unknown at plan time when
# the prefix is created in the same run, and count has to be known then
data "netbox_prefix" "node" {
  count = var.netbox_node_prefix_lookup ? 1 : 0

  prefix = var.netbox_node_prefix
}

# Per-node resources, tracked by node key
resource "netbox_virtual_machine" "this" {
  for_each = toset(var.node_keys)

  cluster_id   = data.netbox_cluster.this.id
  site_id      = var.netbox_site_id
  role_id      = data.netbox_device_role.this.id
  name         = "${var.node_prefix}${each.key}"
  disk_size_mb = var.disk * 1024
  memory_mb    = var.memory
  vcpus        = var.cores
}

resource "netbox_interface" "this" {
  for_each = toset(var.node_keys)

  name               = var.device_networkcard_name
  virtual_machine_id = netbox_virtual_machine.this[each.key].id
}

resource "netbox_available_ip_address" "this" {
  for_each = toset(var.node_keys)

  prefix_id    = local.node_prefix_id
  status       = "active"
  interface_id = netbox_interface.this[each.key].id
  object_type  = "virtualization.vminterface"
  dns_name     = "${var.node_prefix}${each.key}.${var.domain_name}"

  lifecycle {
    precondition {
      condition     = var.netbox_node_prefix_lookup || var.netbox_node_prefix_id != null
      error_message = "Set netbox_node_prefix_id, or set netbox_node_prefix_lookup to true."
    }
    precondition {
      condition     = !(var.netbox_node_prefix_lookup && var.netbox_node_prefix_id != null)
      error_message = "Set either netbox_node_prefix_id or netbox_node_prefix_lookup, not both."
    }
  }
}

resource "netbox_primary_ip" "this" {
  for_each = toset(var.node_keys)

  ip_address_id      = netbox_available_ip_address.this[each.key].id
  ip_address_version = 6
  virtual_machine_id = netbox_virtual_machine.this[each.key].id
}
