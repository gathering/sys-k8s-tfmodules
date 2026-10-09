output "neighbor_ips_by_key" {
  description = "Addresses of the BGP neighbors, by the keys of `neighbors_by_key`"
  value       = { for k, n in fortios_routerbgp_neighbor.this : k => n.ip }
}

output "prefix_list_in_name" {
  description = "Name of the inbound IPv6 prefix list"
  value       = fortios_router_prefixlist6.in.name
}

output "prefix_list_out_name" {
  description = "Name of the outbound IPv6 prefix list"
  value       = fortios_router_prefixlist6.out.name
}
