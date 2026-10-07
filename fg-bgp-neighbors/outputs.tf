output "neighbor_ips" {
  description = "Addresses of the BGP neighbors from `neighbors`, in the order of that list"
  value       = fortios_routerbgp_neighbor.this[*].ip
}

output "neighbor_ips_by_key" {
  description = "Addresses of the BGP neighbors from `neighbors_by_key`, by key"
  value       = { for k, n in fortios_routerbgp_neighbor.keyed : k => n.ip }
}

output "prefix_list_in_name" {
  description = "Name of the inbound IPv6 prefix list"
  value       = fortios_router_prefixlist6.in.name
}

output "prefix_list_out_name" {
  description = "Name of the outbound IPv6 prefix list"
  value       = fortios_router_prefixlist6.out.name
}
