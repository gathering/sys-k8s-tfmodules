# Node addressing and placement, with every provider mocked.
#
# Runs share one state and the VM ignores changes to node_name and initialization, so
# placement and gateway are only visible on VMs that do not exist yet. The runs that check
# them therefore only plan; the two that apply come last.

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

# Mocked as well: these tests are about addressing and placement, not about the rendered config
mock_provider "talos" {}

variables {
  cluster_name          = "test"
  node_prefix           = "n-"
  type                  = "worker"
  nodes                 = 2
  cluster_ip            = "2001:db8::1"
  talos_version         = "v1.11.0"
  kubernetes_version    = "1.34.0"
  netbox_node_prefix    = "2001:db8:0:1::/64"
  netbox_node_prefix_id = 42
  node_vlan_vid         = 100
  netbox_site_id        = 1
  pod_subnets           = ["2001:db8:42::/56"]
  service_subnets       = ["2001:db8:42:100::/112"]

  # Placeholders: the mocked talos provider does not read them
  talos_machine_secrets = {
    certs = {
      etcd               = { cert = "dGVzdA==", key = "dGVzdA==" }
      k8s                = { cert = "dGVzdA==", key = "dGVzdA==" }
      k8s_aggregator     = { cert = "dGVzdA==", key = "dGVzdA==" }
      k8s_serviceaccount = { key = "dGVzdA==" }
      os                 = { cert = "dGVzdA==", key = "dGVzdA==" }
    }
    cluster = { id = "dGVzdA==", secret = "dGVzdA==" }
    secrets = {
      bootstrap_token             = "abcdef.0123456789abcdef"
      secretbox_encryption_secret = "dGVzdA=="
    }
    trustdinfo = { token = "abcdef.0123456789abcdef" }
  }
  talos_client_configuration = {
    ca_certificate     = "dGVzdA=="
    client_certificate = "dGVzdA=="
    client_key         = "dGVzdA=="
  }
}

run "defaults" {
  command = plan

  assert {
    condition     = netbox_available_ip_address.this[*].prefix_id == [42, 42] && length(data.netbox_prefix.node) == 0
    error_message = "A given prefix id must be used as is, without a lookup."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[0].initialization[0].ip_config[0].ipv6[0].gateway == "2001:db8:0:1::1"
    error_message = "The gateway must default to host 1 of the node prefix."
  }

  assert {
    condition     = keys(proxmox_virtual_environment_file.this) == ["pve1", "pve2", "pve3"]
    error_message = "The snippet must go to every host by default, offline ones included."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[*].node_name == ["pve1", "pve2"]
    error_message = "Nodes must be placed on the hosts in API order by default."
  }

  assert {
    condition = alltrue([
      proxmox_virtual_environment_vm.this[0].clone[0].vm_id == 9201,
      proxmox_virtual_environment_vm.this[0].clone[0].node_name == "pve1",
      proxmox_virtual_environment_vm.this[0].on_boot == false,
      proxmox_virtual_environment_vm.this[0].agent[0].enabled == true,
      proxmox_virtual_environment_vm.this[0].tags == tolist(["kubernetes", "terraform"]),
      proxmox_virtual_environment_vm.this[0].description == "Managed by Undercloud (Terraform)",
      proxmox_virtual_environment_file.this["pve1"].datastore_id == "local",
    ])
    error_message = "A default no longer matches the value that was hardcoded before v0.1.0."
  }

  assert {
    condition     = length(random_id.this) == 2 && length(netbox_virtual_machine.keyed) == 0 && length(proxmox_virtual_environment_vm.keyed) == 0 && output.nodes_by_key == {}
    error_message = "Without node_keys the nodes must be tracked by position, with random names: existing pools depend on these addresses."
  }

  assert {
    condition     = proxmox_virtual_environment_file.this["pve1"].source_raw[0].file_name == "test-worker.yaml"
    error_message = "The snippet name must stay as it was unless snippet_per_pool is set: existing VMs point at it."
  }

  assert {
    condition     = alltrue([for a in talos_machine_configuration_apply.this : a.apply_mode == "staged_if_needing_reboot"])
    error_message = "Config changes that need a reboot must be staged by default."
  }

  assert {
    condition     = alltrue([for a in talos_machine_configuration_apply.this : a.on_destroy == { graceful = true, reset = false, reboot = false }])
    error_message = "Removed nodes must not be reset by default: that is the behaviour before v0.1.0."
  }
}

run "apply_mode_and_on_destroy" {
  command = plan

  variables {
    apply_mode = "auto"
    on_destroy = { reset = true }
  }

  assert {
    condition     = talos_machine_configuration_apply.this[0].apply_mode == "auto"
    error_message = "apply_mode must reach the config apply."
  }

  assert {
    condition     = talos_machine_configuration_apply.this[0].on_destroy == { graceful = true, reset = true, reboot = false }
    error_message = "on_destroy must reach the config apply, with unset keys at their defaults."
  }
}

run "apply_mode_is_validated" {
  command = plan

  variables {
    apply_mode = "try"
  }

  expect_failures = [
    var.apply_mode,
  ]
}

run "snippet_per_pool" {
  command = plan

  variables {
    snippet_per_pool = true
    node_prefix      = "pool-a-"
  }

  assert {
    condition     = alltrue([for f in proxmox_virtual_environment_file.this : f.source_raw[0].file_name == "test-worker-pool-a.yaml"])
    error_message = "With snippet_per_pool the snippet name must contain the node prefix."
  }
}

run "snippet_per_pool_needs_a_node_prefix" {
  command = plan

  variables {
    snippet_per_pool = true
    node_prefix      = ""
  }

  expect_failures = [
    proxmox_virtual_environment_file.this,
  ]
}

run "gateway_and_prefix_lookup" {
  command = plan

  variables {
    gateway                   = "fe80::1"
    netbox_node_prefix_id     = null
    netbox_node_prefix_lookup = true
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[0].initialization[0].ip_config[0].ipv6[0].gateway == "fe80::1"
    error_message = "A given gateway must be used as is."
  }

  assert {
    condition     = data.netbox_prefix.node[0].prefix == "2001:db8:0:1::/64" && netbox_available_ip_address.this[*].prefix_id == [77, 77]
    error_message = "The prefix id must come from the Netbox lookup of netbox_node_prefix."
  }
}

run "prefix_id_or_lookup_is_required" {
  command = plan

  variables {
    netbox_node_prefix_id = null
  }

  expect_failures = [
    netbox_available_ip_address.this,
  ]
}

run "placement_wraps_around" {
  command = plan

  variables {
    nodes = 5
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[*].node_name == ["pve1", "pve2", "pve3", "pve1", "pve2"]
    error_message = "A pool larger than the host count must wrap around."
  }
}

run "placement_online_only" {
  command = plan

  variables {
    nodes               = 3
    proxmox_online_only = true
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[*].node_name == ["pve1", "pve3", "pve1"]
    error_message = "New VMs must skip the offline host."
  }

  assert {
    condition     = keys(proxmox_virtual_environment_file.this) == ["pve1", "pve2", "pve3"]
    error_message = "The snippet must still go to every host."
  }
}

run "placement_pinned" {
  command = plan

  variables {
    nodes               = 3
    proxmox_nodes       = ["pve3", "pve1"]
    proxmox_online_only = true
    template_vm_id      = 9000
    template_node_name  = "pve3"
    snippet_datastore   = "snippets"
  }

  assert {
    condition     = length(data.proxmox_virtual_environment_nodes.available_nodes) == 0
    error_message = "Pinned hosts must not need the host lookup."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[*].node_name == ["pve3", "pve1", "pve3"]
    error_message = "Nodes must follow the order of proxmox_nodes."
  }

  assert {
    condition     = keys(proxmox_virtual_environment_file.this) == ["pve1", "pve3"]
    error_message = "The snippet must only go to the pinned hosts."
  }

  assert {
    condition = alltrue([
      proxmox_virtual_environment_vm.this[0].clone[0].vm_id == 9000,
      proxmox_virtual_environment_vm.this[0].clone[0].node_name == "pve3",
      proxmox_virtual_environment_file.this["pve3"].datastore_id == "snippets",
    ])
    error_message = "Template and snippet datastore inputs must reach the resources."
  }
}

run "prefix_other_than_64" {
  override_resource {
    target = netbox_available_ip_address.this
    values = {
      id         = "301"
      ip_address = "2001:db8:0:100::abcd/56"
    }
  }

  variables {
    type               = "controlplane"
    netbox_node_prefix = "2001:db8:0:100::/56"
  }

  assert {
    condition     = output.nodes_ip == ["2001:db8:0:100::abcd", "2001:db8:0:100::abcd"]
    error_message = "The prefix length must be split off for any prefix size."
  }

  assert {
    condition     = output.nodes[*].ip == output.nodes_ip && output.nodes[*].name == random_id.this[*].hex
    error_message = "The nodes output must pair each name with its address."
  }

  assert {
    condition     = talos_machine_bootstrap.this[0].node == "2001:db8:0:100::abcd" && talos_machine_configuration_apply.this[1].node == "2001:db8:0:100::abcd"
    error_message = "Talos must be addressed without the prefix length."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[0].initialization[0].ip_config[0].ipv6[0].address == "2001:db8:0:100::abcd/56"
    error_message = "The VM address must keep its prefix length."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[0].initialization[0].ip_config[0].ipv6[0].gateway == "2001:db8:0:100::1"
    error_message = "The gateway must default to host 1 of the node prefix."
  }
}

run "existing_vms_do_not_move" {
  override_resource {
    target = netbox_available_ip_address.this
    values = {
      id         = "301"
      ip_address = "2001:db8:0:100::abcd/56"
    }
  }

  variables {
    type               = "controlplane"
    netbox_node_prefix = "2001:db8:0:100::/56"
    proxmox_nodes      = ["pve3"]
    gateway            = "fe80::1"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[*].node_name == ["pve1", "pve2"]
    error_message = "Existing VMs must stay on their host when placement inputs change."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this[0].initialization[0].ip_config[0].ipv6[0].gateway == "2001:db8:0:100::1"
    error_message = "Cloud-init of existing VMs must not change."
  }
}

run "subnets_are_required" {
  command = plan

  variables {
    pod_subnets     = []
    service_subnets = ["2001:db8:42:100::1"]
  }

  expect_failures = [
    var.pod_subnets,
    var.service_subnets,
  ]
}

run "controlplane_pool_needs_a_node" {
  command = plan

  variables {
    type  = "controlplane"
    nodes = 0
  }

  expect_failures = [
    data.talos_machine_configuration.this,
  ]
}
