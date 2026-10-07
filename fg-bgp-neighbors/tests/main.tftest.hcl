# Neighbors and prefix lists, with the provider mocked.
#
# These runs check which neighbors exist and what they are configured with. They cannot
# show that a remaining neighbor is left alone: a mock makes up the computed values again
# on every run. That needs the actions of a plan with the real provider, see "How this was
# verified" in UPGRADING.md.

mock_provider "fortios" {}

variables {
  cluster_name = "test"
  prefixes = [
    { prefix = "2001:db8:1::/48", ge = 64 },
    { prefix = "2001:db8:2::/64", ge = 128, le = 128 },
  ]
}

run "neighbors_as_a_list" {
  command = plan

  variables {
    neighbors = [
      { name = "test-cp-1a2b", ip = "2001:db8:0:1::a" },
      { name = "test-cp-3c4d", ip = "2001:db8:0:1::b" },
    ]
  }

  assert {
    condition = [for n in fortios_routerbgp_neighbor.this : [n.ip, n.remote_as, n.description, n.prefix_list_in6, n.prefix_list_out6]] == [
      ["2001:db8:0:1::a", "64513", "Cluster: test Node: test-cp-1a2b", "test-in", "test-out"],
      ["2001:db8:0:1::b", "64513", "Cluster: test Node: test-cp-3c4d", "test-in", "test-out"],
    ]
    error_message = "Neighbors from the list must be tracked by position, with the default AS and the cluster's prefix lists: existing deployments depend on it."
  }

  assert {
    condition     = length(fortios_routerbgp_neighbor.keyed) == 0
    error_message = "A list must not create neighbors tracked by key."
  }

  assert {
    condition = [for r in fortios_router_prefixlist6.in.rule : [r.id, r.action, r.prefix6, r.ge, r.le == null ? -1 : r.le]] == [
      [1, "permit", "2001:db8:1::/48", 64, -1],
      [2, "permit", "2001:db8:2::/64", 128, 128],
    ]
    error_message = "Without ids the prefix-list rules must be numbered by position, with ge and le as given."
  }

  assert {
    condition     = [for r in fortios_router_prefixlist6.out.rule : [r.id, r.action, r.prefix6]] == [[1, "deny", "any"]]
    error_message = "The outbound prefix list must deny everything."
  }
}

run "neighbors_by_key" {
  variables {
    neighbors_by_key = {
      test-cp-a = { name = "test-cp-a", ip = "2001:db8:0:1::a" }
      test-cp-b = { name = "test-cp-b", ip = "2001:db8:0:1::b" }
      test-w-a  = { name = "test-w-a", ip = "2001:db8:0:1::c" }
    }
    prefixes = [
      { id = 10, prefix = "2001:db8:1::/48", ge = 64 },
      { id = 20, prefix = "2001:db8:2::/64", ge = 128, le = 128 },
      { id = 30, prefix = "2001:db8:3::/64" },
    ]
  }

  assert {
    condition = { for k, n in fortios_routerbgp_neighbor.keyed : k => [n.ip, n.remote_as, n.description, n.prefix_list_in6, n.prefix_list_out6] } == {
      test-cp-a = ["2001:db8:0:1::a", "64513", "Cluster: test Node: test-cp-a", "test-in", "test-out"]
      test-cp-b = ["2001:db8:0:1::b", "64513", "Cluster: test Node: test-cp-b", "test-in", "test-out"]
      test-w-a  = ["2001:db8:0:1::c", "64513", "Cluster: test Node: test-w-a", "test-in", "test-out"]
    }
    error_message = "Neighbors from the map must be tracked by key and configured like those from the list."
  }

  assert {
    condition     = length(fortios_routerbgp_neighbor.this) == 0
    error_message = "A map must not create neighbors tracked by position."
  }

  assert {
    condition     = output.neighbor_ips_by_key == { test-cp-a = "2001:db8:0:1::a", test-cp-b = "2001:db8:0:1::b", test-w-a = "2001:db8:0:1::c" }
    error_message = "neighbor_ips_by_key must carry the keys of neighbors_by_key."
  }

  assert {
    condition     = [for r in fortios_router_prefixlist6.in.rule : [r.id, r.prefix6]] == [[10, "2001:db8:1::/48"], [20, "2001:db8:2::/64"], [30, "2001:db8:3::/64"]]
    error_message = "Explicit rule ids must be used as given."
  }
}

run "without_the_middle_neighbor_and_rule" {
  variables {
    neighbors_by_key = {
      test-cp-a = { name = "test-cp-a", ip = "2001:db8:0:1::a" }
      test-w-a  = { name = "test-w-a", ip = "2001:db8:0:1::c" }
      test-w-b  = { name = "test-w-b", ip = "2001:db8:0:1::d" }
    }
    prefixes = [
      { id = 10, prefix = "2001:db8:1::/48", ge = 64 },
      { id = 30, prefix = "2001:db8:3::/64" },
    ]
  }

  assert {
    condition     = { for k, n in fortios_routerbgp_neighbor.keyed : k => [n.ip, n.description] } == { test-cp-a = ["2001:db8:0:1::a", "Cluster: test Node: test-cp-a"], test-w-a = ["2001:db8:0:1::c", "Cluster: test Node: test-w-a"], test-w-b = ["2001:db8:0:1::d", "Cluster: test Node: test-w-b"] }
    error_message = "Removing and adding a neighbor must leave key and configuration of the others as they were."
  }

  assert {
    condition     = [for r in fortios_router_prefixlist6.in.rule : [r.id, r.prefix6]] == [[10, "2001:db8:1::/48"], [30, "2001:db8:3::/64"]]
    error_message = "Removing a rule must leave the ids of the others as they were."
  }
}

run "list_and_map_together" {
  command = plan

  variables {
    neighbors = [
      { name = "test-cp-1a2b", ip = "2001:db8:0:1::1" },
    ]
    neighbors_by_key = {
      test-w-a = { name = "test-w-a", ip = "2001:db8:0:1::c" }
    }
  }

  assert {
    condition     = length(fortios_routerbgp_neighbor.this) == 1 && keys(fortios_routerbgp_neighbor.keyed) == ["test-w-a"]
    error_message = "A cluster with pools of both kinds must be able to pass both."
  }
}

run "second_instance_for_a_cluster" {
  command = plan

  variables {
    prefix_list_name = "test-workers"
    remote_as        = "64999"
  }

  assert {
    condition     = output.prefix_list_in_name == "test-workers-in" && output.prefix_list_out_name == "test-workers-out"
    error_message = "prefix_list_name must name both prefix lists."
  }

  assert {
    condition     = fortios_router_prefixlist6.in.comments == "Cluster: test - Prefix list in"
    error_message = "The comment must still name the cluster."
  }
}

run "prefixes_must_not_be_empty" {
  command = plan

  variables {
    prefixes = []
  }

  expect_failures = [
    var.prefixes,
  ]
}

run "rule_ids_on_all_or_none" {
  command = plan

  variables {
    prefixes = [
      { id = 1, prefix = "2001:db8:1::/48" },
      { prefix = "2001:db8:2::/64" },
    ]
  }

  expect_failures = [
    var.prefixes,
  ]
}

run "rule_ids_must_be_unique" {
  command = plan

  variables {
    prefixes = [
      { id = 1, prefix = "2001:db8:1::/48" },
      { id = 1, prefix = "2001:db8:2::/64" },
    ]
  }

  expect_failures = [
    var.prefixes,
  ]
}

run "rule_ids_must_be_whole_numbers_from_1" {
  command = plan

  variables {
    prefixes = [
      { id = 0, prefix = "2001:db8:1::/48" },
      { id = 1.5, prefix = "2001:db8:2::/64" },
    ]
  }

  expect_failures = [
    var.prefixes,
  ]
}
