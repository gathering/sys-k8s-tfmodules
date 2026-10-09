# VIPs and policy, with the provider mocked. The policy is an fg-policy module call, so
# its arguments are checked in fg-policy/tests (run "as_called_by_fg_k8slb").

mock_provider "fortios" {}

variables {
  cluster_name = "test"
  extip        = "2001:db8::1"
  realservers_by_key = {
    a = { id = 3, ip = "2001:db8:0:1::a" }
    b = { id = 10, ip = "2001:db8:0:1::b" }
    c = { id = 2, ip = "2001:db8:0:1::c" }
  }
  dstintf  = ["vlan100"]
  srcintf  = ["wan1", "wan2"]
  srcaddr6 = ["all"]
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
      [2, "2001:db8:0:1::c", 50000],
      [3, "2001:db8:0:1::a", 50000],
      [10, "2001:db8:0:1::b", 50000],
    ]
    error_message = "Realservers must carry their given ids, in id order, and use the VIP port."
  }

  assert {
    condition = { for k, vip in fortios_firewall_vip6.this : k => vip.comment } == {
      k8s-api           = "Kubernetes API of cluster test. Managed by OpenTofu"
      talos-control-api = "Talos trustd of cluster test. Managed by OpenTofu"
      talosctl-api      = "Talos API (apid) of cluster test. Managed by OpenTofu"
    }
    error_message = "Each VIP must say which API of which cluster it is."
  }

  assert {
    condition     = output.vip_names == { k8s-api = "test-k8s-api", talos-control-api = "test-talos-control-api", talosctl-api = "test-talosctl-api" }
    error_message = "The vip_names output must keep its keys."
  }
}

run "realservers_by_key_without_the_middle_one" {
  command = plan

  variables {
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

run "realservers_must_not_be_empty" {
  command = plan

  variables {
    realservers_by_key = {}
  }

  expect_failures = [
    var.realservers_by_key,
  ]
}

run "null_gives_the_default" {
  command = plan

  variables {
    monitor         = null
    ssl_ssh_profile = null
  }

  assert {
    condition     = alltrue([for vip in fortios_firewall_vip6.this : toset(vip.monitor[*].name) == toset(["tcp-check"])])
    error_message = "A null monitor must give the module default."
  }
}

run "realserver_ids_must_be_unique" {
  command = plan

  variables {
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
