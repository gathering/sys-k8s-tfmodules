# Node keys, with every provider mocked. The runs share one state: the pool is
# created, loses its middle node and gets a new one.
#
# These runs check which instances exist and what they are configured with. They cannot
# show that a remaining node is left alone: a mock gives every instance the same computed
# values and makes them up again on every run. That needs the actions of a plan with the
# real providers.

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
  mock_resource "proxmox_virtual_environment_file" {
    defaults = {
      id = "local:snippets/mock.yaml"
    }
  }
}

mock_provider "talos" {}

variables {
  cluster_name          = "test"
  node_prefix           = "test-cp-"
  type                  = "controlplane"
  node_keys             = ["a", "b", "c"]
  cluster_ip            = "2001:db8::1"
  talos_version         = "v1.11.0"
  kubernetes_version    = "1.34.0"
  netbox_node_prefix    = "2001:db8:0:1::/64"
  netbox_node_prefix_id = 42
  node_vlan_vid         = 100
  netbox_site_id        = 1
  pod_subnets           = ["2001:db8:42::/56"]
  service_subnets       = ["2001:db8:42:100::/112"]
  proxmox_nodes         = ["pve1", "pve2", "pve3"]

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

# First plan of a new pool: names and addresses do not exist yet
run "plan_new_pool" {
  command = plan

  assert {
    condition = alltrue([
      keys(netbox_virtual_machine.this) == ["a", "b", "c"],
      keys(netbox_interface.this) == ["a", "b", "c"],
      keys(netbox_available_ip_address.this) == ["a", "b", "c"],
      keys(netbox_primary_ip.this) == ["a", "b", "c"],
      keys(proxmox_virtual_environment_vm.this) == ["a", "b", "c"],
      keys(talos_machine_configuration_apply.this) == ["a", "b", "c"],
    ])
    error_message = "Every per-node resource must be tracked by node key."
  }

  assert {
    condition     = { for key, vm in proxmox_virtual_environment_vm.this : key => [vm.name, vm.smbios[0].serial, vm.node_name] } == { a = ["test-cp-a", "h=test-cp-a", "pve1"], b = ["test-cp-b", "h=test-cp-b", "pve2"], c = ["test-cp-c", "h=test-cp-c", "pve3"] }
    error_message = "A node must be named <node_prefix><key> and placed by its position in node_keys."
  }

  assert {
    condition     = { for key, ip in netbox_available_ip_address.this : key => ip.dns_name } == { a = "test-cp-a.gathering.systems", b = "test-cp-b.gathering.systems", c = "test-cp-c.gathering.systems" }
    error_message = "Each node address must get the DNS name <node_prefix><key>.<domain_name>."
  }

  assert {
    condition     = keys(output.nodes_by_key) == ["a", "b", "c"] && [for node in values(output.nodes_by_key) : node.name] == ["test-cp-a", "test-cp-b", "test-cp-c"]
    error_message = "Keys and names of nodes_by_key must be known before the addresses exist: other modules use them as for_each keys."
  }

}

run "create_pool" {
  assert {
    condition     = keys(output.nodes_by_key) == ["a", "b", "c"] && values(output.nodes_by_key)[*].ip == ["2001:db8:0:1::abcd", "2001:db8:0:1::abcd", "2001:db8:0:1::abcd"]
    error_message = "The outputs must list every node, with the address without its prefix length."
  }

  assert {
    condition     = talos_machine_bootstrap.this[0].node == "2001:db8:0:1::abcd" && talos_cluster_kubeconfig.this[0].node == "2001:db8:0:1::abcd"
    error_message = "Bootstrap and kubeconfig must use a node address without the prefix length."
  }

  assert {
    condition     = alltrue([for key in ["a", "b", "c"] : talos_machine_configuration_apply.this[key].node == "2001:db8:0:1::abcd" && proxmox_virtual_environment_vm.this[key].initialization[0].ip_config[0].ipv6[0].address == "2001:db8:0:1::abcd/64"])
    error_message = "Each node must get its address on the VM and as the target of its config apply."
  }
}

run "remove_middle_node" {
  variables {
    node_keys = ["a", "c"]
  }

  assert {
    condition = alltrue([
      keys(netbox_virtual_machine.this) == ["a", "c"],
      keys(netbox_interface.this) == ["a", "c"],
      keys(netbox_available_ip_address.this) == ["a", "c"],
      keys(netbox_primary_ip.this) == ["a", "c"],
      keys(proxmox_virtual_environment_vm.this) == ["a", "c"],
      keys(talos_machine_configuration_apply.this) == ["a", "c"],
    ])
    error_message = "Removing a key must remove that node and no other."
  }

  assert {
    condition     = output.nodes_by_key == { a = { name = "test-cp-a", ip = "2001:db8:0:1::abcd" }, c = { name = "test-cp-c", ip = "2001:db8:0:1::abcd" } }
    error_message = "nodes_by_key must list the remaining nodes only, under their names."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this["c"].node_name == "pve3"
    error_message = "A node must stay on its host when its position in node_keys changes."
  }
}

run "add_node" {
  variables {
    node_keys = ["a", "c", "d"]
  }

  assert {
    condition     = keys(proxmox_virtual_environment_vm.this) == ["a", "c", "d"] && keys(netbox_available_ip_address.this) == ["a", "c", "d"]
    error_message = "Adding a key must add that node and no other."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this["d"].name == "test-cp-d" && proxmox_virtual_environment_vm.this["d"].node_name == "pve3"
    error_message = "A new node must be named after its key and placed by its position in node_keys."
  }

  assert {
    condition     = keys(output.nodes_by_key) == ["a", "c", "d"] && values(output.nodes_by_key)[*].name == ["test-cp-a", "test-cp-c", "test-cp-d"]
    error_message = "The outputs must list the nodes of node_keys."
  }
}

run "domain_name" {
  command = plan

  variables {
    domain_name = "example.org"
  }

  assert {
    condition     = netbox_available_ip_address.this["a"].dns_name == "test-cp-a.example.org"
    error_message = "domain_name must be the domain of the node's DNS name."
  }
}

run "domain_name_is_validated" {
  command = plan

  variables {
    domain_name = "not a domain"
  }

  expect_failures = [
    var.domain_name,
  ]
}

run "empty_pool" {
  command = plan

  variables {
    type      = "worker"
    node_keys = []
  }

  assert {
    condition     = length(netbox_virtual_machine.this) == 0 && output.nodes_by_key == {}
    error_message = "An empty node_keys must give an empty pool."
  }
}

# Only a worker pool may be empty: there is no node to bootstrap otherwise
run "empty_controlplane_pool_is_rejected" {
  command = plan

  variables {
    node_keys = []
  }

  expect_failures = [
    output.cluster_name,
  ]
}

run "duplicate_keys_are_rejected" {
  command = plan

  variables {
    node_keys = ["a", "b", "a"]
  }

  expect_failures = [
    var.node_keys,
  ]
}

run "keys_must_fit_a_hostname" {
  command = plan

  variables {
    node_keys = ["a", "B_1"]
  }

  expect_failures = [
    var.node_keys,
  ]
}
