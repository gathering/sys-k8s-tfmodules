# One cluster built from all five modules. The nodes are tracked by key (node_keys), which is
# the mode to use for a new cluster: any node can be removed without touching the others.
#
# The module sources are relative so that CI validates this example against the modules of
# the same commit. In your own root module, pin a release instead:
#   source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//talos?ref=v0.1.0"

# Endpoints and credentials come from the providers' environment variables
provider "netbox" {}

provider "proxmox" {}

provider "fortios" {}

resource "talos_machine_secrets" "this" {}

module "vlan" {
  source = "../../fg-vlan"

  name                   = var.cluster_name
  netbox_vlan_group_name = var.netbox_vlan_group_name
  netbox_role_id         = var.netbox_role_id
  netbox_base_prefix     = var.netbox_base_prefix
}

module "controlplane" {
  source = "../../talos"

  cluster_name               = var.cluster_name
  node_prefix                = "${var.cluster_name}-cp-"
  type                       = "controlplane"
  node_keys                  = keys(var.controlplane_nodes)
  cluster_ip                 = var.cluster_ip
  talos_version              = var.talos_version
  kubernetes_version         = var.kubernetes_version
  talos_machine_secrets      = talos_machine_secrets.this.machine_secrets
  talos_client_configuration = talos_machine_secrets.this.client_configuration
  pod_subnets                = var.pod_subnets
  service_subnets            = var.service_subnets
  proxmox_nodes              = var.proxmox_nodes
  snippet_per_pool           = true

  # The prefix is created in this configuration, so pass its id. netbox_node_prefix_lookup
  # is for a prefix that already exists
  netbox_node_prefix    = module.vlan.prefix
  netbox_node_prefix_id = module.vlan.prefix_id
  node_vlan_vid         = module.vlan.vlan_vid
  netbox_site_id        = var.netbox_site_id
}

# No depends_on on the control plane: a module-level depends_on defers every data source in
# the module to apply time. The workers' config apply retries until the API answers.
module "workers" {
  source = "../../talos"

  cluster_name               = var.cluster_name
  node_prefix                = "${var.cluster_name}-w-"
  type                       = "worker"
  node_keys                  = var.worker_keys
  cores                      = 4
  memory                     = 8192
  cluster_ip                 = var.cluster_ip
  talos_version              = var.talos_version
  kubernetes_version         = var.kubernetes_version
  talos_machine_secrets      = talos_machine_secrets.this.machine_secrets
  talos_client_configuration = talos_machine_secrets.this.client_configuration
  pod_subnets                = var.pod_subnets
  service_subnets            = var.service_subnets
  proxmox_nodes              = var.proxmox_nodes
  snippet_per_pool           = true

  netbox_node_prefix    = module.vlan.prefix
  netbox_node_prefix_id = module.vlan.prefix_id
  node_vlan_vid         = module.vlan.vlan_vid
  netbox_site_id        = var.netbox_site_id
}

module "k8s_lb" {
  source = "../../fg-k8slb"

  cluster_name = var.cluster_name
  extip        = var.cluster_ip
  dstintf      = [module.vlan.interface_name]
  srcintf      = var.api_source_interfaces
  srcaddr6     = var.api_source_addresses

  realservers_by_key = {
    for key, id in var.controlplane_nodes : key => { id = id, ip = module.controlplane.nodes_by_key[key].ip }
  }
}

module "bgp_neighbors" {
  source = "../../fg-bgp-neighbors"

  cluster_name = var.cluster_name
  prefixes     = var.bgp_prefixes

  # By node name: keys of two pools may be the same, names are not
  neighbors_by_key = {
    for node in concat(values(module.controlplane.nodes_by_key), values(module.workers.nodes_by_key)) : node.name => node
  }
}

module "egress" {
  source = "../../fg-policy"

  name     = "${var.cluster_name}-egress"
  srcintf  = [module.vlan.interface_name]
  srcaddr6 = [module.vlan.firewall_address_name]
  dstintf  = [var.wan_interface]
  dstaddr6 = ["all"]
  services = ["ALL"]
}
