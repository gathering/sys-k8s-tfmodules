# Neighbors and prefix lists, with the provider mocked.
#
# These runs check which neighbors exist and what they are configured with. They cannot
# show that a remaining neighbor is left alone: a mock makes up the computed values again
# on every run. That needs the actions of a plan with the real provider.

mock_provider "fortios" {}

variables {
  cluster_name = "test"
  neighbors_by_key = {
    test-cp-a = { name = "test-cp-a", ip = "2001:db8:0:1::a" }
  }
  prefixes = [
    { prefix = "2001:db8:1::/48", ge = 64 },
    { prefix = "2001:db8:2::/64", ge = 128, le = 128 },
  ]
}

run "prefix_lists" {
  command = plan

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
    condition = { for k, n in fortios_routerbgp_neighbor.this : k => [n.ip, n.remote_as, n.description, n.prefix_list_in6, n.prefix_list_out6] } == {
      test-cp-a = ["2001:db8:0:1::a", "64513", "Cluster: test Node: test-cp-a", "test-in", "test-out"]
      test-cp-b = ["2001:db8:0:1::b", "64513", "Cluster: test Node: test-cp-b", "test-in", "test-out"]
      test-w-a  = ["2001:db8:0:1::c", "64513", "Cluster: test Node: test-w-a", "test-in", "test-out"]
    }
    error_message = "Neighbors must be tracked by key, with the default AS and the cluster's prefix lists."
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
    condition     = { for k, n in fortios_routerbgp_neighbor.this : k => [n.ip, n.description] } == { test-cp-a = ["2001:db8:0:1::a", "Cluster: test Node: test-cp-a"], test-w-a = ["2001:db8:0:1::c", "Cluster: test Node: test-w-a"], test-w-b = ["2001:db8:0:1::d", "Cluster: test Node: test-w-b"] }
    error_message = "Removing and adding a neighbor must leave key and configuration of the others as they were."
  }

  assert {
    condition     = [for r in fortios_router_prefixlist6.in.rule : [r.id, r.prefix6]] == [[10, "2001:db8:1::/48"], [30, "2001:db8:3::/64"]]
    error_message = "Removing a rule must leave the ids of the others as they were."
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

run "null_gives_the_default" {
  command = plan

  variables {
    remote_as = null
  }

  assert {
    condition     = fortios_routerbgp_neighbor.this["test-cp-a"].remote_as == "64513"
    error_message = "A null remote_as must give the module default."
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
