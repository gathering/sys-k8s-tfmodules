locals {
  cluster_endpoint = "https://[${var.cluster_ip}]:6443"

  cluster_oidc = {
    oidc-issuer-url      = var.oidc_issuer_url == "" ? null : var.oidc_issuer_url
    oidc-client-id       = var.oidc_client_id == "" ? null : var.oidc_client_id
    oidc-username-claim  = var.oidc_username_claim == "" ? null : var.oidc_username_claim
    oidc-username-prefix = var.oidc_username_prefix == "" ? null : var.oidc_username_prefix
    oidc-groups-claim    = var.oidc_groups_claim == "" ? null : var.oidc_groups_claim
    oidc-groups-prefix   = var.oidc_groups_prefix == "" ? null : var.oidc_groups_prefix
  }

  cluster_apiserver_extraArgs = merge(var.oidc_issuer_url == "" ? local.cluster_oidc : {}, {})

  machine = {
    network = {
      nameservers = var.nameservers
    }
    features = {
      kubePrism = {
        enabled = true
        port    = 7445
      }
    }
    time = {
      disabled = false
      servers  = var.time_servers
    }
    certSANs = [
      "localhost",
      var.cluster_ip
    ]
  }

  cluster = {
    allowSchedulingOnControlPlanes = var.allow_scheduling_on_control_planes
    network = {
      cni = {
        name = "none"
      }
      podSubnets     = var.pod_subnets
      serviceSubnets = var.service_subnets
    }
    proxy = {
      disabled = true
    }
    discovery = {
      enabled = true
      registries = {
        kubernetes = {
          disabled = true
        }
        service = {
          disabled = false
        }
      }
    }
    apiServer = {
      certSANs = [
        "localhost",
        var.cluster_ip
      ]
      extraArgs = local.cluster_apiserver_extraArgs
    }
  }

  controlplane_config_patches = [yamlencode(merge({ machine = local.machine, cluster = local.cluster })), yamlencode({ cluster = { inlineManifests = var.talos_inline_manifests } })]
  worker_config_patches       = [yamlencode(merge({ machine = local.machine, cluster = local.cluster }))]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = var.talos_client_configuration
  endpoints            = [var.cluster_ip]
  nodes                = [for ip in netbox_available_ip_address.this[*].ip_address : trimsuffix(ip, "/64")]
}

# resource "local_file" "talosclientconfig" {
#   count = var.type == "controlplane" ? 1 : 0

#   content  = data.talos_client_configuration.this.talos_config
#   filename = "${path.root}/talosconfig-${var.cluster_name}"
# }
