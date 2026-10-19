output "netbox_vlan_name" {
  description = "Name of the VLAN in Netbox, as given in `name`. Also the alias of the FortiGate interface"
  value       = var.name
}

output "interface_name" {
  description = "FortiGate interface name of the VLAN (`vlan<VLAN ID>`)"
  value       = fortios_system_interface.this.name
}

output "vlan_vid" {
  description = "VLAN ID (802.1Q tag), not the Netbox ID of the VLAN"
  value       = netbox_available_vlan.this.vid
}

output "prefix" {
  description = "Prefix of the VLAN in CIDR notation"
  value       = netbox_available_prefix.this.prefix
}

output "prefix_id" {
  description = "Netbox ID of the prefix"
  value       = netbox_available_prefix.this.id
}

output "firewall_address_name" {
  description = "Name of the FortiGate IPv6 address object for the prefix"
  value       = fortios_firewall_address6.this.name
}

output "gateway_ip" {
  description = "IPv6 address of the gateway on the VLAN, host 1 of the prefix, without a prefix length"
  value       = cidrhost(netbox_available_prefix.this.prefix, 1)
}

output "gateway_dns_name" {
  description = "DNS name of the gateway address in Netbox (`gw.<name>.<domain_name>`). Null when `domain_name` is null"
  value       = local.gateway_dns_name
}
