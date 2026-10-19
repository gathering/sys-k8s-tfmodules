# One cluster built from every module but ceph-storage, whose provider only loads on Linux with
# librados installed. The nodes are tracked by key (node_keys): any node can be removed without
# touching the others.
#
# The module sources are relative so that CI validates this example against the modules of
# the same commit. In your own root module, pin a release instead:
#   source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//talos?ref=v0.7.0"

# Endpoints and credentials come from the providers' environment variables
provider "netbox" {}

provider "proxmox" {}

provider "fortios" {}

provider "keycloak" {}

# The poweradmin provider reads no environment variables
provider "poweradmin" {
  api_url = var.poweradmin_url
  api_key = var.poweradmin_api_key
}

locals {
  api_dns_name = "api.${var.cluster_name}.${var.domain_name}"
}

resource "talos_machine_secrets" "this" {}

# The client kubectl logs in to the cluster with, through kubelogin
module "kubernetes_client" {
  source = "../../keycloak-client"

  realm_name          = var.keycloak_realm_name
  name                = "${var.cluster_name}-cli"
  display_name        = "${var.cluster_name} - Kubernetes API"
  access_type         = "PUBLIC"
  valid_redirect_uris = ["http://localhost:8000", "http://localhost:18000"]
}

module "vlan" {
  source = "../../fg-vlan"

  name                   = var.cluster_name
  netbox_vlan_group_name = var.netbox_vlan_group_name
  netbox_role_id         = var.netbox_role_id
  netbox_base_prefix     = var.netbox_base_prefix
  domain_name            = var.domain_name
}

module "controlplane" {
  source = "../../talos"

  cluster_name               = var.cluster_name
  node_prefix                = "${var.cluster_name}-cp-"
  type                       = "controlplane"
  node_keys                  = keys(var.controlplane_nodes)
  cluster_ip                 = var.cluster_ip
  extra_cert_sans            = [local.api_dns_name]
  domain_name                = var.domain_name
  talos_version              = var.talos_version
  kubernetes_version         = var.kubernetes_version
  talos_machine_secrets      = talos_machine_secrets.this.machine_secrets
  talos_client_configuration = talos_machine_secrets.this.client_configuration
  pod_subnets                = var.pod_subnets
  service_subnets            = var.service_subnets
  proxmox_nodes              = var.proxmox_nodes

  # The prefix is created in this configuration, so pass its id. netbox_node_prefix_lookup
  # is for a prefix that already exists
  netbox_node_prefix    = module.vlan.prefix
  netbox_node_prefix_id = module.vlan.prefix_id
  node_vlan_vid         = module.vlan.vlan_vid
  netbox_site_id        = var.netbox_site_id

  # Members of the Keycloak group <cluster_name>-cluster-admin are cluster admin
  oidc = {
    issuer_url = "${var.keycloak_url}/realms/${var.keycloak_realm_name}"
    client_id  = module.kubernetes_client.client_id
  }
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
  domain_name                = var.domain_name
  talos_version              = var.talos_version
  kubernetes_version         = var.kubernetes_version
  running_kubernetes_version = module.controlplane.running_kubernetes_version
  talos_machine_secrets      = talos_machine_secrets.this.machine_secrets
  talos_client_configuration = talos_machine_secrets.this.client_configuration
  pod_subnets                = var.pod_subnets
  service_subnets            = var.service_subnets
  proxmox_nodes              = var.proxmox_nodes

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

# Forward records only: the reverse records come from automation in Netbox, from the DNS
# names the talos and fg-vlan modules set on the addresses
module "dns" {
  source = "../../dns-records"

  zone_name = var.domain_name

  records_by_key = merge(
    {
      api     = { name = local.api_dns_name, values = [var.cluster_ip] }
      gateway = { name = module.vlan.gateway_dns_name, values = [module.vlan.gateway_ip] }
      # Any other record, here a CNAME for the API
      kubernetes = { name = "kubernetes.${var.cluster_name}.${var.domain_name}", type = "CNAME", values = ["${local.api_dns_name}."] }
    },
    # By node name, like the BGP neighbors
    {
      for node in concat(values(module.controlplane.nodes_by_key), values(module.workers.nodes_by_key)) :
      node.name => { name = "${node.name}.${var.domain_name}", values = [node.ip] }
    },
  )
}
