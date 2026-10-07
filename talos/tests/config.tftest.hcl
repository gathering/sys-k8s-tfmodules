# Machine config rendering. The talos provider is real: its data sources render locally
# from the secrets the setup module generates. Netbox and Proxmox are mocked. The Talos
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
  nodes                 = 1
  cluster_ip            = "2001:db8::1"
  talos_version         = "v1.11.0"
  kubernetes_version    = "1.34.0"
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
    condition     = yamldecode(data.talos_machine_configuration.this.machine_configuration).machine.type == "controlplane"
    error_message = "Expected a control-plane machine config."
  }

  assert {
    condition     = length(local.controlplane_config_patches) == 1 && data.talos_machine_configuration.this.config_patches == tolist(local.controlplane_config_patches)
    error_message = "Control planes must get the single control-plane patch."
  }

  assert {
    condition     = length(try(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.apiServer.extraArgs, {})) == 0
    error_message = "No API server arguments expected with OIDC off."
  }

  assert {
    condition     = yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.inlineManifests[*].name == ["extra"]
    error_message = "With OIDC off, control planes must get talos_inline_manifests and no OIDC binding."
  }

  assert {
    condition = alltrue([
      yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.network.cni.name == "none",
      yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.proxy.disabled,
      yamldecode(data.talos_machine_configuration.this.machine_configuration).machine.features.kubePrism.enabled,
    ])
    error_message = "CNI none, kube-proxy disabled and kubePrism on are part of the design."
  }

  assert {
    condition     = output.kubeconfig != "" && output.talosconfig != ""
    error_message = "Control planes must output kubeconfig and talosconfig."
  }
}

run "empty_strings_equal_null" {
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
    oidc_issuer_url            = ""
    oidc_client_id             = ""
  }

  assert {
    condition     = length(try(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.apiServer.extraArgs, {})) == 0
    error_message = "Empty OIDC strings must turn OIDC off, like null."
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
    oidc_issuer_url            = "https://sso.example.org/realms/test"
    oidc_client_id             = "kubernetes"
    oidc_username_prefix       = ""
  }

  assert {
    condition = yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.apiServer.extraArgs == {
      oidc-client-id      = "kubernetes"
      oidc-groups-claim   = "groups"
      oidc-groups-prefix  = "oidc:"
      oidc-issuer-url     = "https://sso.example.org/realms/test"
      oidc-username-claim = "preferred_username"
    }
    error_message = "Unexpected OIDC API server arguments: unset inputs must be left out."
  }

  assert {
    condition     = yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.inlineManifests[*].name == ["oidc-test-cluster-admin", "extra"]
    error_message = "Control planes must get the OIDC binding followed by talos_inline_manifests."
  }

  assert {
    condition     = yamldecode(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.inlineManifests[0].contents).subjects[0].name == "oidc:test-cluster-admin"
    error_message = "The binding must name the group with the default groups prefix."
  }

  # The default group is rendered unquoted; a change here re-applies the config on every control plane
  assert {
    condition     = endswith(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.inlineManifests[0].contents, "  kind: Group\n  name: oidc:test-cluster-admin\n")
    error_message = "The binding must render the default group unquoted."
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
    oidc_issuer_url            = "https://sso.example.org/realms/test"
    oidc_client_id             = "kubernetes"
    oidc_groups_prefix         = "* #"
  }

  assert {
    condition     = yamldecode(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.inlineManifests[0].contents).subjects[0].name == "* #test-cluster-admin"
    error_message = "The binding must use oidc_groups_prefix, also when it needs quoting in YAML."
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
    oidc_issuer_url            = "https://sso.example.org/realms/test"
    oidc_client_id             = "kubernetes"
    oidc_groups_prefix         = null
  }

  assert {
    condition     = yamldecode(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.inlineManifests[0].contents).subjects[0].name == "test-cluster-admin"
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
    talos_machine_secrets      = run.setup.machine_secrets
    talos_client_configuration = run.setup.client_configuration
    type                       = "worker"
    nodes                      = 2
    pod_subnets                = ["2001:db8:42::/56"]
    oidc_issuer_url            = "https://sso.example.org/realms/test"
    oidc_client_id             = "kubernetes"
  }

  assert {
    condition     = yamldecode(data.talos_machine_configuration.this.machine_configuration).machine.type == "worker"
    error_message = "Expected a worker machine config."
  }

  assert {
    condition     = length(local.worker_config_patches) == 1 && data.talos_machine_configuration.this.config_patches == tolist(local.worker_config_patches)
    error_message = "Workers must get the single worker patch."
  }

  assert {
    condition = length(setintersection(keys(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster), [
      "allowSchedulingOnControlPlanes", "apiServer", "inlineManifests", "proxy",
    ])) == 0 && !contains(keys(yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.network), "cni")
    error_message = "Workers must not get settings that only control planes act on."
  }

  assert {
    condition     = !strcontains(local.worker_config_patches[0], "oidc") && !strcontains(local.worker_config_patches[0], "extra")
    error_message = "OIDC settings and talos_inline_manifests must only reach control planes."
  }

  assert {
    condition = alltrue([
      yamldecode(data.talos_machine_configuration.this.machine_configuration).machine.features.kubePrism.enabled,
      yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.discovery.registries.kubernetes.disabled,
      yamldecode(data.talos_machine_configuration.this.machine_configuration).cluster.network.podSubnets == ["2001:db8:42::/56"],
    ])
    error_message = "Workers must keep the settings every node uses."
  }

  assert {
    condition     = length(talos_machine_bootstrap.this) == 0 && length(talos_cluster_kubeconfig.this) == 0
    error_message = "Workers must not bootstrap or fetch a kubeconfig."
  }

  assert {
    condition     = output.kubeconfig == "" && output.talosconfig == ""
    error_message = "Workers must not output credentials."
  }
}

run "issuer_without_client_id_is_rejected" {
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
    oidc_issuer_url            = "https://sso.example.org/realms/test"
  }

  expect_failures = [
    data.talos_machine_configuration.this,
  ]
}
