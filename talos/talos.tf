locals {
  kube_apiserver_port = 6443
  kubeprism_port      = 7445

  cluster_endpoint = "https://[${var.cluster_ip}]:${local.kube_apiserver_port}"

  cert_sans = [
    "localhost",
    var.cluster_ip
  ]

  # API server arguments. Unset inputs (null or "") are left out
  cluster_oidc = {
    for k, v in {
      oidc-issuer-url      = var.oidc_issuer_url
      oidc-client-id       = var.oidc_client_id
      oidc-username-claim  = var.oidc_username_claim
      oidc-username-prefix = var.oidc_username_prefix
      oidc-groups-claim    = var.oidc_groups_claim
      oidc-groups-prefix   = var.oidc_groups_prefix
    } : k => v if v != null && v != ""
  }

  oidc_enabled = contains(keys(local.cluster_oidc), "oidc-issuer-url")

  # The group as kube-apiserver sees it: the groups claim value with the groups prefix in front
  oidc_admin_group = "${lookup(local.cluster_oidc, "oidc-groups-prefix", "")}${var.cluster_name}-cluster-admin"

  # The group is quoted only when YAML needs it. Quoting the default too would change the
  # rendered config and re-apply it on every control plane
  oidc_inline_manifests = local.oidc_enabled ? [
    {
      name     = "oidc-${var.cluster_name}-cluster-admin"
      contents = <<-EOT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oidc-${var.cluster_name}-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: ${can(regex("^[A-Za-z0-9][A-Za-z0-9:._-]*$", local.oidc_admin_group)) ? local.oidc_admin_group : jsonencode(local.oidc_admin_group)}
EOT
    }
  ] : []

  machine = {
    network = {
      nameservers = var.nameservers
    }
    features = {
      kubePrism = {
        enabled = true
        port    = local.kubeprism_port
      }
    }
    time = {
      disabled = false
      servers  = var.time_servers
    }
    certSANs = local.cert_sans
  }

  # Cluster settings every node uses
  cluster = {
    network = {
      podSubnets     = var.pod_subnets
      serviceSubnets = var.service_subnets
    }
    discovery = {
      enabled = var.discovery_enabled
      registries = {
        kubernetes = {
          disabled = true
        }
        service = {
          disabled = false
          endpoint = var.discovery_service_endpoint
        }
      }
    }
  }

  # Cluster settings Talos only acts on for control planes
  cluster_controlplane = {
    allowSchedulingOnControlPlanes = var.allow_scheduling_on_control_planes
    network = merge(local.cluster.network, {
      cni = {
        name = "none"
      }
    })
    proxy = {
      disabled = true
    }
    apiServer = {
      certSANs  = local.cert_sans
      extraArgs = local.oidc_enabled ? local.cluster_oidc : {}
    }
    inlineManifests = concat(local.oidc_inline_manifests, var.talos_inline_manifests)
  }

  controlplane_config_patches = [yamlencode({ machine = local.machine, cluster = merge(local.cluster, local.cluster_controlplane) })]
  worker_config_patches       = [yamlencode({ machine = local.machine, cluster = local.cluster })]
}

data "talos_machine_configuration" "this" {
  cluster_name       = var.cluster_name
  machine_type       = var.type
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = var.talos_machine_secrets
  docs               = false
  examples           = false
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = var.type == "controlplane" ? local.controlplane_config_patches : local.worker_config_patches

  lifecycle {
    precondition {
      condition     = !local.oidc_enabled || contains(keys(local.cluster_oidc), "oidc-client-id")
      error_message = "oidc_client_id must be set when oidc_issuer_url is set: kube-apiserver does not start with only one of them."
    }

    # Checked here because bootstrap and kubeconfig have no instance in an empty pool
    precondition {
      condition     = var.type != "controlplane" || local.pool_size > 0
      error_message = "A control-plane pool needs at least one node: set nodes to 1 or more, or give node_keys at least one key."
    }
  }
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = var.talos_client_configuration
  endpoints            = [var.cluster_ip]
  nodes                = local.node_ips
}

# We only bootstrap the first controlplane
resource "talos_machine_bootstrap" "this" {
  count = local.bootstrap ? 1 : 0

  node                 = local.node_ips[0]
  client_configuration = var.talos_client_configuration

  # A keyed pool waits for all its VMs: depends_on cannot pick the first key
  depends_on = [
    proxmox_virtual_environment_vm.this[0],
    proxmox_virtual_environment_vm.keyed
  ]
}

resource "talos_machine_configuration_apply" "this" {
  count = local.node_count

  client_configuration        = var.talos_client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = local.node_ips[count.index]
  apply_mode                  = var.apply_mode

  # Spelled out: the provider fails on an object that is unknown as a whole, which a
  # variable is during validate
  on_destroy = {
    graceful = var.on_destroy.graceful
    reset    = var.on_destroy.reset
    reboot   = var.on_destroy.reboot
  }

  # Every VM must exist and, for control planes, etcd must be bootstrapped before config is applied
  depends_on = [
    proxmox_virtual_environment_vm.this,
    talos_machine_bootstrap.this
  ]
}

# Same as above for a pool with node_keys. Keep the two in sync
resource "talos_machine_configuration_apply" "keyed" {
  for_each = toset(local.node_keys)

  client_configuration        = var.talos_client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = split("/", netbox_available_ip_address.keyed[each.key].ip_address)[0]
  apply_mode                  = var.apply_mode

  on_destroy = {
    graceful = var.on_destroy.graceful
    reset    = var.on_destroy.reset
    reboot   = var.on_destroy.reboot
  }

  # Every VM must exist and, for control planes, etcd must be bootstrapped before config is applied
  depends_on = [
    proxmox_virtual_environment_vm.keyed,
    talos_machine_bootstrap.this
  ]
}

resource "talos_cluster_kubeconfig" "this" {
  count = local.bootstrap ? 1 : 0

  client_configuration = var.talos_client_configuration
  # For unknown reason this is super unstable when using the VIP (I guess that is technically not a node)
  # So using one of the node IPs directly
  node = local.node_ips[0]

  depends_on = [
    talos_machine_bootstrap.this
  ]
}
