output "cluster_name" {
  description = "Cluster Name"
  value       = var.cluster_name
}

output "nodes" {
  description = "List of all nodes as objects with `name` and `ip`. With `node_keys`, in the order of that list"
  value       = [for i, name in local.node_names : { name = name, ip = local.node_ips[i] }]
}

output "nodes_ip" {
  description = "List of IPv6 address to all nodes. With `node_keys`, in the order of that list"
  value       = local.node_ips
}

output "nodes_by_key" {
  description = "Nodes of a pool with `node_keys` as a map from key to an object with `name` and `ip`. The keys are known at plan time. Empty without `node_keys`"
  value       = { for i, key in local.node_keys : key => { name = local.node_names[i], ip = local.node_ips[i] } }
}

output "talosconfig" {
  description = "Talosctl config. Output only on type controlplane"
  sensitive   = true
  value       = var.type == "controlplane" ? data.talos_client_configuration.this.talos_config : ""
}

output "kubeconfig" {
  description = "Kubeconfig. Output only on type controlplane"
  sensitive   = true
  value       = local.bootstrap ? talos_cluster_kubeconfig.this[0].kubeconfig_raw : ""
}

output "controlplane_config_patches" {
  description = "Config patches of a control plane: one patch with the settings for every node, the control-plane settings and the inline manifests"
  value       = local.controlplane_config_patches
}

output "worker_config_patches" {
  description = "Config patches of a worker: one patch with the settings for every node"
  value       = local.worker_config_patches
}
