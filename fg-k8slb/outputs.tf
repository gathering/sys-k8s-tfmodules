output "vip_names" {
  description = "Names of the VIPs, keyed by `k8s-api`, `talos-control-api` and `talosctl-api`"
  value       = { for k, vip in fortios_firewall_vip6.this : k => vip.name }
}

output "policy_id" {
  description = "ID of the firewall policy"
  value       = module.policy.policy_id
}
