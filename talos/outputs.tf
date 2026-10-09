output "cluster_name" {
  description = "Cluster Name"
  value       = var.cluster_name
}

output "nodes_by_key" {
  description = "Nodes as a map from node key to an object with `name` and `ip`. The keys and names are known at plan time"
  value       = { for i, key in var.node_keys : key => { name = "${var.node_prefix}${key}", ip = local.node_ips[i] } }
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

output "config_patches" {
  description = "Config patches of the pool, one patch. For a worker the settings every node uses; for a control plane also the control-plane settings and the inline manifests"
  value       = local.config_patches
}
