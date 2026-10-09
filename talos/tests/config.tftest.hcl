# Machine config rendering. The talos provider is real: its data sources render locally
# from the secrets the setup module generates. The config is a stream of documents: an
# assert picks the documents of one kind out of it by how each starts. Netbox and Proxmox are mocked. The Talos
# resources that talk to a node are overridden in each run, because a file-level override
# would also have to match the setup module.

mock_provider "netbox" {
  mock_data "netbox_cluster" {
    defaults = {
      id = 7
    }
  }

  mock_data "netbox_device_role" {
    defaults = {
      id = 8
    }
  }

  mock_data "netbox_prefix" {
    defaults = {
      id = 77
    }
  }

  mock_resource "netbox_virtual_machine" {
    defaults = {
      id = "101"
    }
  }

  mock_resource "netbox_interface" {
    defaults = {
      id = "201"
    }
  }

  mock_resource "netbox_available_ip_address" {
    defaults = {
      id         = "301"
      ip_address = "2001:db8:0:1::abcd/64"
    }
  }
}

mock_provider "proxmox" {
  mock_data "proxmox_virtual_environment_nodes" {
    defaults = {
      names  = ["pve1", "pve2", "pve3"]
      online = [true, false, true]
    }
  }

  mock_resource "proxmox_virtual_environment_file" {
    defaults = {
      id = "local:snippets/mock.yaml"
    }
  }
}

variables {
  cluster_name          = "test"
  node_prefix           = "n-"
  node_keys             = ["a"]
  cluster_ip            = "2001:db8::1"
  talos_version         = "v1.14.2"
  kubernetes_version    = "v1.35.5"
  netbox_node_prefix    = "2001:db8:0:1::/64"
  netbox_node_prefix_id = 42
  node_vlan_vid         = 100
  netbox_site_id        = 1
  pod_subnets           = ["2001:db8:42::/56"]
  service_subnets       = ["2001:db8:42:100::/112"]
  talos_inline_manifests = [
    { name = "extra", contents = "apiVersion: v1\nkind: Namespace\nmetadata:\n  name: extra\n" },
  ]
}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "controlplane_without_oidc" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
  }

  assert {
    condition     = yamldecode(split("\n---\n", data.talos_machine_configuration.this.machine_configuration)[0]).machine.type == "controlplane" && yamldecode(split("\n---\n", data.talos_machine_configuration.this.machine_configuration)[0]).machine.certSANs == ["localhost", "2001:db8::1"]
    error_message = "Expected a control-plane machine config with the certificate SANs."
  }

  assert {
    condition     = output.config_patches == tolist(local.controlplane_config_patches) && data.talos_machine_configuration.this.config_patches == tolist(local.controlplane_config_patches)
    error_message = "Control planes must get the control-plane patches."
  }

  assert {
    condition     = [for kind in ["KubeProxyConfig", "KubeFlannelCNIConfig", "KubePrismConfig", "KubeAPIServerConfig", "KubeNodeConfig"] : length([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : d if startswith(d, "apiVersion: v1alpha1\nkind: ${kind}\n")])] == [0, 0, 1, 1, 1]
    error_message = "No kube-proxy, no Flannel and KubePrism on are part of the design."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeAPIServerConfig\n")][0].certExtraSANs == ["localhost", "2001:db8::1"] && [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubePrismConfig\n")][0].port == 7445
    error_message = "The API server certificate must have the cluster address, and KubePrism its port."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeNetworkConfig\n")][0].podSubnets == ["2001:db8:42::/56"] && [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeNetworkConfig\n")][0].serviceSubnets == ["2001:db8:42:100::/112"]
    error_message = "The pod and service subnets must replace the ones Talos generates."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: ResolverConfig\n")][0].nameservers == [{ address = "2606:4700:4700::64" }] && [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: TimeSyncConfig\n")][0].ntp.servers == ["time.cloudflare.com"]
    error_message = "Nameservers and time servers must be set."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: DiscoveryServiceConfig\n")][*].endpoint == ["https://discovery.talos.dev:443/"]
    error_message = "The discovery service must be on with the default endpoint."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeNodeConfig\n")][0].taints == { "node-role.kubernetes.io/control-plane" = "NoSchedule" }
    error_message = "Control planes must keep the NoSchedule taint unless scheduling on them is allowed."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeAuthenticationConfig\n")][0].configuration.jwt == []
    error_message = "No OIDC issuer expected with OIDC off."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeInlineManifestConfig\n")][*].name == ["extra"]
    error_message = "With OIDC off, control planes must get talos_inline_manifests and no OIDC binding."
  }

  assert {
    condition     = output.kubeconfig != "" && output.talosconfig != ""
    error_message = "Control planes must output kubeconfig and talosconfig."
  }
}

run "scheduling_on_control_planes" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets              = run.setup.machine_secrets
    talos_client_configuration         = run.setup.client_configuration
    type                               = "controlplane"
    allow_scheduling_on_control_planes = true
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : can(yamldecode(d).taints) if startswith(d, "apiVersion: v1alpha1\nkind: KubeNodeConfig\n")] == [false]
    error_message = "With scheduling allowed a control plane must have no taint."
  }
}

run "discovery_off" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
    discovery_enabled          = false
  }

  assert {
    condition     = length([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: DiscoveryServiceConfig\n")]) == 0
    error_message = "With discovery off there must be no discovery service."
  }
}

run "null_oidc_attributes_give_the_defaults" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
    oidc = {
      issuer_url      = "https://sso.example.org/realms/test"
      client_id       = "kubernetes"
      audiences       = null
      username_claim  = null
      username_prefix = null
      groups_claim    = null
      groups_prefix   = null
    }
  }

  assert {
    condition = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeAuthenticationConfig\n")][0].configuration.jwt == [{
      issuer = {
        url                 = "https://sso.example.org/realms/test"
        audiences           = ["kubernetes"]
        audienceMatchPolicy = "MatchAny"
      }
      claimMappings = {
        username = { claim = "preferred_username", prefix = "oidc:" }
        groups   = { claim = "groups", prefix = "oidc:" }
      }
    }]
    error_message = "A null claim, prefix or audiences must give its default."
  }
}

run "controlplane_with_oidc" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
    oidc                       = { issuer_url = "https://sso.example.org/realms/test", client_id = "kubernetes", audiences = ["dashboard", "kubernetes"], username_prefix = "" }
  }

  assert {
    condition = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeAuthenticationConfig\n")][0].configuration == {
      anonymous = {
        enabled    = true
        conditions = [{ path = "/livez" }, { path = "/readyz" }, { path = "/healthz" }]
      }
      jwt = [{
        issuer = {
          url                 = "https://sso.example.org/realms/test"
          audiences           = ["kubernetes", "dashboard"]
          audienceMatchPolicy = "MatchAny"
        }
        claimMappings = {
          username = { claim = "preferred_username", prefix = "" }
          groups   = { claim = "groups", prefix = "oidc:" }
        }
      }]
    }
    error_message = "Unexpected authentication configuration: client_id first, then the other audiences, the claims as given, and anonymous requests to the health endpoints only."
  }

  assert {
    condition     = !can([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeAPIServerConfig\n")][0].extraArgs) && !can(yamldecode(split("\n---\n", data.talos_machine_configuration.this.machine_configuration)[0]).machine.files)
    error_message = "OIDC must not need API server arguments or files: Talos owns the authentication configuration."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeInlineManifestConfig\n")][*].name == ["oidc-test-cluster-admin", "extra"]
    error_message = "Control planes must get the OIDC binding followed by talos_inline_manifests."
  }

  assert {
    condition     = yamldecode([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeInlineManifestConfig\n")][0].manifest).subjects[0].name == "oidc:test-cluster-admin"
    error_message = "The binding must name the group with the default groups prefix."
  }
}

run "oidc_without_groups_claim" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
    oidc                       = { issuer_url = "https://sso.example.org/realms/test", client_id = "kubernetes", groups_claim = "" }
  }

  assert {
    condition     = keys([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeAuthenticationConfig\n")][0].configuration.jwt[0].claimMappings) == ["username"]
    error_message = "Without a groups claim there must be no groups mapping."
  }
}

run "oidc_groups_prefix_names_the_group" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
    oidc                       = { issuer_url = "https://sso.example.org/realms/test", client_id = "kubernetes", groups_prefix = "* #" }
  }

  assert {
    condition     = yamldecode([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeInlineManifestConfig\n")][0].manifest).subjects[0].name == "* #test-cluster-admin"
    error_message = "The binding must use groups_prefix, also when it needs quoting in YAML."
  }
}

run "oidc_without_groups_prefix" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
    oidc                       = { issuer_url = "https://sso.example.org/realms/test", client_id = "kubernetes", groups_prefix = "" }
  }

  assert {
    condition     = yamldecode([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeInlineManifestConfig\n")][0].manifest).subjects[0].name == "test-cluster-admin"
    error_message = "Without a groups prefix the binding must name the bare group."
  }
}

run "worker" {
  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets              = run.setup.machine_secrets
    talos_client_configuration         = run.setup.client_configuration
    type                               = "worker"
    node_keys                          = ["a", "b"]
    oidc                               = { issuer_url = "https://sso.example.org/realms/test", client_id = "kubernetes" }
    allow_scheduling_on_control_planes = true
  }

  assert {
    condition     = yamldecode(split("\n---\n", data.talos_machine_configuration.this.machine_configuration)[0]).machine.type == "worker"
    error_message = "Expected a worker machine config."
  }

  assert {
    condition     = output.config_patches == tolist(local.worker_config_patches) && data.talos_machine_configuration.this.config_patches == tolist(local.worker_config_patches)
    error_message = "Workers must get the worker patches."
  }

  assert {
    condition     = [for kind in ["KubeAPIServerConfig", "KubeAuthenticationConfig", "KubeInlineManifestConfig", "KubeProxyConfig", "KubeFlannelCNIConfig"] : length([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : d if startswith(d, "apiVersion: v1alpha1\nkind: ${kind}\n")])] == [0, 0, 0, 0, 0]
    error_message = "Workers must not get what only control planes act on."
  }

  assert {
    condition     = alltrue([for patch in output.config_patches : !strcontains(patch, "oidc") && !strcontains(patch, "extra") && !strcontains(patch, "KubeNodeConfig")])
    error_message = "OIDC settings, talos_inline_manifests and the scheduling setting must only reach control planes."
  }

  assert {
    condition     = [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubeNetworkConfig\n")][0].podSubnets == ["2001:db8:42::/56"] && [for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: KubePrismConfig\n")][0].port == 7445 && length([for d in split("\n---\n", data.talos_machine_configuration.this.machine_configuration) : yamldecode(d) if startswith(d, "apiVersion: v1alpha1\nkind: DiscoveryServiceConfig\n")]) == 1
    error_message = "Workers must keep the settings every node uses."
  }
}

run "oidc_needs_issuer_client_id_and_username_claim" {
  command = plan

  override_resource {
    target = talos_machine_bootstrap.this
  }

  override_resource {
    target = talos_machine_configuration_apply.this
  }

  override_resource {
    target = talos_cluster_kubeconfig.this
  }

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "controlplane"
    oidc                       = { issuer_url = "https://sso.example.org/realms/test", client_id = "" }
  }

  expect_failures = [
    var.oidc,
  ]
}

run "talos_version_before_1_14_is_rejected" {
  command = plan

  variables {
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "worker"
    talos_version              = "v1.13.2"
  }

  expect_failures = [
    var.talos_version,
  ]
}
