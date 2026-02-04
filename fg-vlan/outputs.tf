output "name" {
  description = "Interface Name"
  value       = var.name
}

output "vlan_name" {
  description = "VLAN Name"
  value       = fortios_system_interface.this.name
}

output "vlan_id" {
  description = "VLAN ID"
  value       = netbox_available_vlan.this.vid
}

output "prefix" {
  description = "Prefix"
  value       = netbox_available_prefix.this.prefix
}

output "prefix_id" {
  description = "Prefix ID"
  value       = netbox_available_prefix.this.id
}

output "firewall_address_name" {
  description = "firewall_address_name"
  value       = fortios_firewall_address6.this.name
}
