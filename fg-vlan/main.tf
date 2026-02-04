## Get data from netbox
data "netbox_vlan_group" "this" {
  name = var.vlan_group
}
data "netbox_prefix" "this" {
  prefix = var.base_prefix
}

## Create VLAN in Netbox
resource "netbox_available_vlan" "this" {
  name        = var.name
  role_id     = var.netbox_role_id
  group_id    = data.netbox_vlan_group.this.id
  status      = "active"
  description = "VLAN for ${var.name}"
}

## Create prefix in Netbox
resource "netbox_available_prefix" "this" {
  parent_prefix_id = data.netbox_prefix.this.id
  prefix_length    = var.prefix_length
  description      = "VLAN for ${var.name} (VLAN ${netbox_available_vlan.this.vid})"
  vlan_id          = netbox_available_vlan.this.id
  role_id          = var.netbox_role_id
  status           = "active"
}

## Reserve gateway in Netbox
resource "netbox_ip_address" "gw" {
  ip_address  = "${cidrhost(netbox_available_prefix.this.prefix, 1)}/${netbox_available_prefix.this.prefix_length}"
  status      = "reserved"
  description = "Reserved for default gateway ${var.name} (VLAN ${netbox_available_vlan.this.vid})"
}

## Create vlan interface on fg
resource "fortios_system_interface" "this" {
  ip                    = "0.0.0.0 0.0.0.0"
  interface             = var.interface
  vlan_protocol         = "8021q"
  vlanid                = netbox_available_vlan.this.vid
  name                  = "vlan${netbox_available_vlan.this.vid}"
  alias                 = netbox_available_vlan.this.name
  type                  = "vlan"
  vdom                  = var.vdom
  mode                  = "static"
  role                  = "lan"
  device_identification = "enable"
  description           = "${var.name} - Created by Terraform Provider for FortiOS"
  ipv6 {
    ip6_mode        = "static"
    ip6_address     = "${cidrhost(netbox_available_prefix.this.prefix, 1)}/${netbox_available_prefix.this.prefix_length}"
    ip6_allowaccess = "ping"
  }
}

## Create firewall address on fg
resource "fortios_firewall_address6" "this" {
  ip6     = netbox_available_prefix.this.prefix
  name    = "vlan${netbox_available_vlan.this.vid} address"
  comment = "${var.name} - Created by Terraform Provider for FortiOS"
}
