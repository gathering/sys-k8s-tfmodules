locals {
  gateway_dns_name = var.domain_name == null ? null : "gw.${var.name}.${var.domain_name}"

  gateway = "${cidrhost(netbox_available_prefix.this.prefix, 1)}/${netbox_available_prefix.this.prefix_length}"
}

## Get data from netbox
data "netbox_vlan_group" "this" {
  name = var.netbox_vlan_group_name
}

data "netbox_prefix" "this" {
  prefix = var.netbox_base_prefix
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
  ip_address  = local.gateway
  status      = "reserved"
  dns_name    = local.gateway_dns_name
  description = "Reserved for default gateway ${var.name} (VLAN ${netbox_available_vlan.this.vid})"

  # Netbox rejects any other DNS name, on apply. Checked here because a variable validation
  # cannot refer to a second variable in OpenTofu 1.8
  lifecycle {
    precondition {
      condition     = local.gateway_dns_name == null ? true : can(regex("^[0-9A-Za-z_-]+(\\.[0-9A-Za-z_-]+)*$", local.gateway_dns_name))
      error_message = "name is part of the gateway's DNS name (gw.<name>.<domain_name>) and may then only contain letters, digits, hyphens, underscores and dots. Set domain_name to null to leave the gateway without a DNS name."
    }
  }
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
  description           = "${var.name} (VLAN ${netbox_available_vlan.this.vid}). Managed by OpenTofu"
  ipv6 {
    ip6_mode        = "static"
    ip6_address     = local.gateway
    ip6_allowaccess = "ping"
  }
}

## Create firewall address on fg
resource "fortios_firewall_address6" "this" {
  ip6     = netbox_available_prefix.this.prefix
  name    = "vlan${netbox_available_vlan.this.vid} address"
  comment = "Prefix of ${var.name} (VLAN ${netbox_available_vlan.this.vid}). Managed by OpenTofu"
}
