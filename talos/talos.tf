locals {
  kube_apiserver_port = 6443

  cluster_endpoint = "https://[${var.cluster_ip}]:${local.kube_apiserver_port}"

  cert_sans = concat(["localhost", var.cluster_ip], var.extra_cert_sans)

  oidc_enabled = var.oidc != null

  oidc_claim_mappings = local.oidc_enabled ? {
    username = { claim = var.oidc.username_claim, prefix = var.oidc.username_prefix }
    groups   = { claim = var.oidc.groups_claim, prefix = var.oidc.groups_prefix }
  } : {}

  # The group as kube-apiserver sees it: the groups claim value with the groups prefix in front
  oidc_admin_group = "${local.oidc_enabled ? var.oidc.groups_prefix : ""}${var.cluster_name}-cluster-admin"

  # The group is quoted only when YAML needs it. Quoting the default too would change the
  # rendered config and re-apply it on every control plane
  oidc_inline_manifests = local.oidc_enabled && try(var.oidc.cluster_admin_binding, false) ? [
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

  # The config is the one Talos generates for talos_version, with the documents below
  # patched in, one patch per document and in this order. A document with `$patch = "delete"`
  # takes the generated one out.

  # What every node gets
  node_config_patches = [
    yamlencode({ machine = { certSANs = local.cert_sans } }),
    yamlencode({ apiVersion = "v1alpha1", kind = "ResolverConfig", nameservers = [for address in var.nameservers : { address = address }] }),
    yamlencode({ apiVersion = "v1alpha1", kind = "TimeSyncConfig", ntp = { servers = var.time_servers } }),
    yamlencode({ apiVersion = "v1alpha1", kind = "KubeNetworkConfig", podSubnets = var.pod_subnets, serviceSubnets = var.service_subnets }),
    var.discovery_enabled
    ? yamlencode({ apiVersion = "v1alpha1", kind = "DiscoveryServiceConfig", name = "default", endpoint = var.discovery_service_endpoint })
    : yamlencode({ apiVersion = "v1alpha1", kind = "DiscoveryServiceConfig", name = "default", "$patch" = "delete" }),
  ]

  # Talos generates the node document of a control plane with the NoSchedule taint and a
  # label that keeps the node out of load balancers. A patch cannot take one label out,
  # so the document is replaced
  scheduling_config_patches = var.allow_scheduling_on_control_planes ? [
    yamlencode({ apiVersion = "v1alpha1", kind = "KubeNodeConfig", "$patch" = "delete" }),
    yamlencode({ apiVersion = "v1alpha1", kind = "KubeNodeConfig", labels = { "node-role.kubernetes.io/control-plane" = "" } }),
  ] : []

  # The patch replaces `configuration` as a whole, so `anonymous` repeats what Talos
  # generates: anonymous requests to the health endpoints only
  oidc_config_patches = local.oidc_enabled ? [
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeAuthenticationConfig"
      configuration = {
        anonymous = {
          enabled    = true
          conditions = [{ path = "/livez" }, { path = "/readyz" }, { path = "/healthz" }]
        }
        jwt = [{
          issuer = {
            url                 = var.oidc.issuer_url
            audiences           = distinct(concat([var.oidc.client_id], var.oidc.audiences))
            audienceMatchPolicy = "MatchAny"
          }
          # Without a groups claim the users are in no groups
          claimMappings = { for k, v in local.oidc_claim_mappings : k => v if v.claim != "" }
        }]
      }
    }),
  ] : []

  # What only control planes get. No kube-proxy and no Flannel: the cluster brings its own CNI
  controlplane_config_patches = concat(
    local.node_config_patches,
    [
      yamlencode({ apiVersion = "v1alpha1", kind = "KubeAPIServerConfig", certExtraSANs = local.cert_sans }),
      yamlencode({ apiVersion = "v1alpha1", kind = "KubeProxyConfig", "$patch" = "delete" }),
      yamlencode({ apiVersion = "v1alpha1", kind = "KubeFlannelCNIConfig", "$patch" = "delete" }),
    ],
    local.scheduling_config_patches,
    local.oidc_config_patches,
    [
      for manifest in concat(local.oidc_inline_manifests, var.talos_inline_manifests) :
      yamlencode({ apiVersion = "v1alpha1", kind = "KubeInlineManifestConfig", name = manifest.name, manifest = manifest.contents })
    ],
  )

  worker_config_patches = local.node_config_patches
  config_patches        = var.type == "controlplane" ? local.controlplane_config_patches : local.worker_config_patches
}

# No preconditions or postconditions here: with one, the data source is read during apply
# whenever something it references has a change pending, even when the value it uses is
# known. The config is then unknown at plan time, which replaces every snippet file and
# re-applies the config on every node. tests/pending_change.tftest.hcl checks this.
data "talos_machine_configuration" "this" {
  cluster_name       = var.cluster_name
  machine_type       = var.type
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = var.talos_machine_secrets
  docs               = false
  examples           = false
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = local.config_patches
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

  # Waits for all VMs of the pool: depends_on cannot pick the first key
  depends_on = [
    proxmox_virtual_environment_vm.this
  ]
}

resource "talos_machine_configuration_apply" "this" {
  for_each = toset(var.node_keys)

  client_configuration        = var.talos_client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = split("/", netbox_available_ip_address.this[each.key].ip_address)[0]
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
