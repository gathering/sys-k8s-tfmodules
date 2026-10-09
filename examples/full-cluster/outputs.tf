output "kubeconfig" {
  description = "Kubeconfig of the cluster"
  sensitive   = true
  value       = module.controlplane.kubeconfig
}

output "talosconfig" {
  description = "Talosctl config of the cluster"
  sensitive   = true
  value       = module.controlplane.talosconfig
}

output "nodes" {
  description = "All nodes as objects with `name` and `ip`"
  value       = concat(values(module.controlplane.nodes_by_key), values(module.workers.nodes_by_key))
}
