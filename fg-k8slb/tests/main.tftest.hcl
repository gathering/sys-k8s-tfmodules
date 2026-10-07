# VIPs and policy, with the provider mocked. The policy is an fg-policy module call, so
# its arguments are checked in fg-policy/tests (run "as_called_by_fg_k8slb").

mock_provider "fortios" {}

variables {
  cluster_name = "test"
  extip        = "2001:db8::1"
  realservers  = ["2001:db8:0:1::c", "2001:db8:0:1::a", "2001:db8:0:1::b"]
  dstintf      = ["vlan100"]
  srcintf      = ["wan1", "wan2"]
  srcaddr6     = ["all"]
}

run "vips" {
  command = plan

  assert {
    condition = { for k, vip in fortios_firewall_vip6.this : k => [vip.name, vip.extport] } == {
      k8s-api           = ["test-k8s-api", "6443"]
      talos-control-api = ["test-talos-control-api", "50001"]
      talosctl-api      = ["test-talosctl-api", "50000"]
    }
    error_message = "VIP keys, names and ports are part of the interface: the keys are state addresses and the names are FortiGate objects."
  }

  assert {
    condition = [for rs in fortios_firewall_vip6.this["talosctl-api"].realservers : [rs.id, rs.ip, rs.port]] == [
      [1, "2001:db8:0:1::a", 50000],
      [2, "2001:db8:0:1::b", 50000],
      [3, "2001:db8:0:1::c", 50000],
    ]
    error_message = "Realservers must be numbered in sorted address order and use the VIP port."
  }

  assert {
    condition     = output.vip_names == { k8s-api = "test-k8s-api", talos-control-api = "test-talos-control-api", talosctl-api = "test-talosctl-api" }
    error_message = "The vip_names output must keep its keys."
  }
}

run "realservers_by_key" {
  command = plan

  variables {
    realservers = null
    realservers_by_key = {
      a = { id = 3, ip = "2001:db8:0:1::a" }
      b = { id = 10, ip = "2001:db8:0:1::b" }
      c = { id = 2, ip = "2001:db8:0:1::c" }
    }
  }

  assert {
    condition = [for rs in fortios_firewall_vip6.this["k8s-api"].realservers : [rs.id, rs.ip, rs.port]] == [
      [2, "2001:db8:0:1::c", 6443],
      [3, "2001:db8:0:1::a", 6443],
      [10, "2001:db8:0:1::b", 6443],
    ]
    error_message = "Realservers must carry their given ids, in id order."
  }
}

run "realservers_by_key_without_the_middle_one" {
  command = plan

  variables {
    realservers = null
    realservers_by_key = {
      b = { id = 10, ip = "2001:db8:0:1::b" }
      c = { id = 2, ip = "2001:db8:0:1::c" }
    }
  }

  assert {
    condition = [for rs in fortios_firewall_vip6.this["k8s-api"].realservers : [rs.id, rs.ip, rs.port]] == [
      [2, "2001:db8:0:1::c", 6443],
      [10, "2001:db8:0:1::b", 6443],
    ]
    error_message = "Removing a realserver must leave id and address of the others as they were."
  }
}

# The ids a list gives are a valid input for the map: this is how an existing load balancer is moved over
run "realservers_by_key_with_the_ids_of_the_list" {
  command = plan

  variables {
    realservers = null
    realservers_by_key = {
      x = { id = 3, ip = "2001:db8:0:1::c" }
      y = { id = 1, ip = "2001:db8:0:1::a" }
      z = { id = 2, ip = "2001:db8:0:1::b" }
    }
  }

  assert {
    condition = [for rs in fortios_firewall_vip6.this["talosctl-api"].realservers : [rs.id, rs.ip, rs.port]] == [
      [1, "2001:db8:0:1::a", 50000],
      [2, "2001:db8:0:1::b", 50000],
      [3, "2001:db8:0:1::c", 50000],
    ]
    error_message = "A map with the ids the list gave must render the same realservers as the list."
  }
}

run "realservers_and_realservers_by_key_exclude_each_other" {
  command = plan

  variables {
    realservers_by_key = {
      a = { id = 1, ip = "2001:db8:0:1::a" }
    }
  }

  expect_failures = [
    fortios_firewall_vip6.this,
  ]
}

run "one_of_realservers_and_realservers_by_key_is_required" {
  command = plan

  variables {
    realservers = null
  }

  expect_failures = [
    fortios_firewall_vip6.this,
  ]
}

run "realserver_ids_must_be_unique" {
  command = plan

  variables {
    realservers = null
    realservers_by_key = {
      a = { id = 1, ip = "2001:db8:0:1::a" }
      b = { id = 1, ip = "2001:db8:0:1::b" }
    }
  }

  expect_failures = [
    var.realservers_by_key,
  ]
}

run "policy_id_output" {
  assert {
    condition     = output.policy_id != null
    error_message = "policy_id must carry the id of the policy in the fg-policy module."
  }
}
