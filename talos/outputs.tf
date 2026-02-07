output "nodes" {
  description = "List of all nodes"
  value       = [for node in proxmox_virtual_environment_vm.this[*] : { name = node.name, ip = trimsuffix(node.initialization[0].ip_config[0].ipv6[0].address, "/64") }]
}

output "nodes_ip" {
  description = "List of IPv6 address to all nodes"
  value       = [for ip in netbox_available_ip_address.this[*].ip_address : trimsuffix(ip, "/64")]
}

output "talosconfig" {
  description = "Talosctl config"
  sensitive   = true
  value       = data.talos_client_configuration.this.talos_config
}

output "kubeconfig" {
  description = "Kubeconfig"
  sensitive   = true
  value       = talos_cluster_kubeconfig.this[0].kubeconfig_raw
}
