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
  node_keys             = ["a", "b"]
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
    condition     = [for ip in netbox_available_ip_address.this : ip.prefix_id] == [42, 42] && length(data.netbox_prefix.node) == 0
    error_message = "A given prefix id must be used as is, without a lookup."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this["a"].initialization[0].ip_config[0].ipv6[0].gateway == "2001:db8:0:1::1"
    error_message = "The gateway must default to host 1 of the node prefix."
  }

  assert {
    condition     = keys(proxmox_virtual_environment_file.this) == ["pve1", "pve2", "pve3"]
    error_message = "The snippet must go to every host by default, offline ones included."
  }

  assert {
    condition     = [for vm in proxmox_virtual_environment_vm.this : vm.node_name] == ["pve1", "pve2"]
    error_message = "Nodes must be placed on the hosts in API order by default."
  }

  assert {
    condition = alltrue([
      proxmox_virtual_environment_vm.this["a"].clone[0].vm_id == 9201,
      proxmox_virtual_environment_vm.this["a"].clone[0].node_name == "pve1",
      proxmox_virtual_environment_vm.this["a"].on_boot == false,
      proxmox_virtual_environment_vm.this["a"].agent[0].enabled == true,
      proxmox_virtual_environment_vm.this["a"].tags == tolist(["kubernetes", "terraform"]),
      proxmox_virtual_environment_vm.this["a"].description == "Talos worker node of Kubernetes cluster test. Managed by OpenTofu: changes made here are overwritten.",
      proxmox_virtual_environment_file.this["pve1"].datastore_id == "local",
    ])
    error_message = "A default differs from the value used at The Gathering."
  }

  assert {
    condition     = alltrue([for f in proxmox_virtual_environment_file.this : f.source_raw[0].file_name == "test-worker-n-.yaml"])
    error_message = "The snippet must be named after cluster, type and the node prefix as given."
  }

  assert {
    condition     = alltrue([for a in talos_machine_configuration_apply.this : a.apply_mode == "staged_if_needing_reboot"])
    error_message = "Config changes that need a reboot must be staged by default."
  }

  assert {
    condition     = alltrue([for a in talos_machine_configuration_apply.this : a.on_destroy == { graceful = true, reset = false, reboot = false }])
    error_message = "Removed nodes must not be reset by default."
  }
}

run "apply_mode_and_on_destroy" {
  command = plan

  variables {
    apply_mode = "auto"
    on_destroy = { reset = true }
  }

  assert {
    condition     = talos_machine_configuration_apply.this["a"].apply_mode == "auto"
    error_message = "apply_mode must reach the config apply."
  }

  assert {
    condition     = talos_machine_configuration_apply.this["a"].on_destroy == { graceful = true, reset = true, reboot = false }
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

# Prefixes that differ only in a trailing separator are different pools
run "snippet_name_keeps_the_prefix_as_given" {
  command = plan

  variables {
    cluster_name = "c1"
    node_prefix  = "wa"
  }

  assert {
    condition     = alltrue([for f in proxmox_virtual_environment_file.this : f.source_raw[0].file_name == "c1-worker-wa.yaml"])
    error_message = "The node prefix must not be trimmed in the snippet name: wa and wa- would share a file."
  }
}

run "snippet_name_with_a_dot" {
  command = plan

  variables {
    node_prefix = "wa."
  }

  assert {
    condition     = alltrue([for f in proxmox_virtual_environment_file.this : f.source_raw[0].file_name == "test-worker-wa..yaml"])
    error_message = "A trailing dot of the node prefix must stay in the snippet name."
  }
}

run "node_prefix_is_required" {
  command = plan

  variables {
    node_prefix = ""
  }

  expect_failures = [
    var.node_prefix,
  ]
}

# The machine config holds the cluster secrets
run "empty_pool_uploads_no_snippet" {
  command = plan

  variables {
    node_keys = []
  }

  assert {
    condition     = length(proxmox_virtual_environment_file.this) == 0 && length(proxmox_virtual_environment_vm.this) == 0
    error_message = "A pool without nodes must not put its machine config on the Proxmox hosts."
  }
}

run "null_gives_the_default" {
  command = plan

  variables {
    cores                      = null
    memory                     = null
    disk                       = null
    discovery_enabled          = null
    discovery_service_endpoint = null
  }

  assert {
    condition = alltrue([
      proxmox_virtual_environment_vm.this["a"].cpu[0].cores == 2,
      proxmox_virtual_environment_vm.this["a"].memory[0].dedicated == 4096,
      proxmox_virtual_environment_vm.this["a"].disk[0].size == 24,
      netbox_virtual_machine.this["a"].vcpus == 2,
      netbox_virtual_machine.this["a"].memory_mb == 4096,
      netbox_virtual_machine.this["a"].disk_size_mb == 24576,
    ])
    error_message = "A null input must give the module default on the VM and in Netbox."
  }

  assert {
    condition     = yamldecode(output.config_patches[0]).cluster.discovery == { enabled = true, registries = { kubernetes = { disabled = true }, service = { disabled = false, endpoint = "https://discovery.talos.dev:443" } } }
    error_message = "A null discovery input must give the module default in the config patch."
  }
}

run "gateway_and_prefix_lookup" {
  command = plan

  variables {
    gateway                   = "fe80::1"
    netbox_node_prefix_id     = null
    netbox_node_prefix_lookup = true
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this["a"].initialization[0].ip_config[0].ipv6[0].gateway == "fe80::1"
    error_message = "A given gateway must be used as is."
  }

  assert {
    condition     = data.netbox_prefix.node[0].prefix == "2001:db8:0:1::/64" && [for ip in netbox_available_ip_address.this : ip.prefix_id] == [77, 77]
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
    node_keys = ["a", "b", "c", "d", "e"]
  }

  assert {
    condition     = [for vm in proxmox_virtual_environment_vm.this : vm.node_name] == ["pve1", "pve2", "pve3", "pve1", "pve2"]
    error_message = "A pool larger than the host count must wrap around."
  }
}

run "placement_online_only" {
  command = plan

  variables {
    node_keys           = ["a", "b", "c"]
    proxmox_online_only = true
  }

  assert {
    condition     = [for vm in proxmox_virtual_environment_vm.this : vm.node_name] == ["pve1", "pve3", "pve1"]
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
    node_keys           = ["a", "b", "c"]
    proxmox_nodes       = ["pve3", "pve1"]
    proxmox_online_only = true
    template_vm_id      = 9000
    template_node_name  = "pve3"
    snippet_datastore   = "snippets"
    description         = "custom"
  }

  assert {
    condition     = length(data.proxmox_virtual_environment_nodes.available_nodes) == 0
    error_message = "Pinned hosts must not need the host lookup."
  }

  assert {
    condition     = [for vm in proxmox_virtual_environment_vm.this : vm.node_name] == ["pve3", "pve1", "pve3"]
    error_message = "Nodes must follow the order of proxmox_nodes."
  }

  assert {
    condition     = keys(proxmox_virtual_environment_file.this) == ["pve1", "pve3"]
    error_message = "The snippet must only go to the pinned hosts."
  }

  assert {
    condition = alltrue([
      proxmox_virtual_environment_vm.this["a"].clone[0].vm_id == 9000,
      proxmox_virtual_environment_vm.this["a"].clone[0].node_name == "pve3",
      proxmox_virtual_environment_file.this["pve3"].datastore_id == "snippets",
      proxmox_virtual_environment_vm.this["a"].description == "custom",
    ])
    error_message = "Template, snippet datastore and description inputs must reach the resources."
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
    condition     = output.nodes_by_key == { a = { name = "n-a", ip = "2001:db8:0:100::abcd" }, b = { name = "n-b", ip = "2001:db8:0:100::abcd" } }
    error_message = "nodes_by_key must pair each name with its address, with the prefix length split off for any prefix size."
  }

  assert {
    condition     = talos_machine_bootstrap.this[0].node == "2001:db8:0:100::abcd" && talos_machine_configuration_apply.this["b"].node == "2001:db8:0:100::abcd"
    error_message = "Talos must be addressed without the prefix length."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this["a"].initialization[0].ip_config[0].ipv6[0].address == "2001:db8:0:100::abcd/56"
    error_message = "The VM address must keep its prefix length."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this["a"].initialization[0].ip_config[0].ipv6[0].gateway == "2001:db8:0:100::1"
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
    condition     = [for vm in proxmox_virtual_environment_vm.this : vm.node_name] == ["pve1", "pve2"]
    error_message = "Existing VMs must stay on their host when placement inputs change."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this["a"].initialization[0].ip_config[0].ipv6[0].gateway == "2001:db8:0:100::1"
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
    type      = "controlplane"
    node_keys = []
  }

  expect_failures = [
    output.cluster_name,
  ]
}
