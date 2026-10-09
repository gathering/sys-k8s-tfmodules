# The policy arguments, with the provider mocked.

mock_provider "fortios" {}

variables {
  name     = "test-egress"
  srcintf  = ["vlan100"]
  srcaddr6 = ["nodes"]
  dstintf  = ["wan1"]
  dstaddr6 = ["all"]
  services = ["HTTPS", "DNS"]
}

run "defaults" {
  command = plan

  assert {
    condition = alltrue([
      fortios_firewall_policy.this.name == "test-egress",
      fortios_firewall_policy.this.action == "accept",
      fortios_firewall_policy.this.inspection_mode == "flow",
      fortios_firewall_policy.this.internet_service == "disable",
      fortios_firewall_policy.this.logtraffic == "all",
      fortios_firewall_policy.this.schedule == "always",
      fortios_firewall_policy.this.status == "enable",
      fortios_firewall_policy.this.ssl_ssh_profile == "SSL-Monitor",
      fortios_firewall_policy.this.comments == "Managed by OpenTofu",
      fortios_firewall_policy.this.nat64 == "disable",
      fortios_firewall_policy.this.ippool == "disable",
    ])
    error_message = "A default no longer gives the expected policy."
  }

  assert {
    condition = alltrue([
      toset(fortios_firewall_policy.this.srcintf[*].name) == toset(["vlan100"]),
      toset(fortios_firewall_policy.this.dstintf[*].name) == toset(["wan1"]),
      toset(fortios_firewall_policy.this.srcaddr6[*].name) == toset(["nodes"]),
      toset(fortios_firewall_policy.this.dstaddr6[*].name) == toset(["all"]),
      toset(fortios_firewall_policy.this.service[*].name) == toset(["HTTPS", "DNS"]),
      length(fortios_firewall_policy.this.srcaddr) == 0,
      length(fortios_firewall_policy.this.dstaddr) == 0,
      length(fortios_firewall_policy.this.poolname) == 0,
    ])
    error_message = "Interfaces, addresses and services must reach the policy, with no IPv4 addresses or pool unless NAT64 is on."
  }
}

run "nat64" {
  command = plan

  variables {
    nat64 = true
  }

  assert {
    condition = alltrue([
      fortios_firewall_policy.this.nat64 == "enable",
      fortios_firewall_policy.this.ippool == "enable",
      toset(fortios_firewall_policy.this.poolname[*].name) == toset(["NAT64-POOL"]),
      toset(fortios_firewall_policy.this.srcaddr[*].name) == toset(["all"]),
      toset(fortios_firewall_policy.this.dstaddr[*].name) == toset(["all"]),
    ])
    error_message = "NAT64 must turn on nat64 and the pool, with IPv4 source and destination all."
  }
}

# The arguments fg-k8slb passes
run "as_called_by_fg_k8slb" {
  command = plan

  variables {
    name     = "test-api-in"
    srcintf  = ["wan1", "wan2"]
    srcaddr6 = ["all"]
    dstintf  = ["vlan100"]
    dstaddr6 = ["test-k8s-api", "test-talos-control-api", "test-talosctl-api"]
    services = ["ALL"]
    comments = "Kubernetes and Talos API of cluster test. Managed by OpenTofu"
    nat      = false
  }

  assert {
    condition     = fortios_firewall_policy.this.comments == "Kubernetes and Talos API of cluster test. Managed by OpenTofu"
    error_message = "A given comment must be used as is."
  }

  assert {
    condition     = fortios_firewall_policy.this.nat == "disable" && fortios_firewall_policy.this.nat64 == "disable"
    error_message = "nat = false must set nat to disable, and NAT64 must be off."
  }

  assert {
    condition     = toset(fortios_firewall_policy.this.srcintf[*].name) == toset(["wan1", "wan2"]) && toset(fortios_firewall_policy.this.dstaddr6[*].name) == toset(["test-k8s-api", "test-talos-control-api", "test-talosctl-api"])
    error_message = "Several interfaces and addresses must all reach the policy."
  }
}

run "null_gives_the_default" {
  command = plan

  variables {
    nat64           = null
    ssl_ssh_profile = null
  }

  assert {
    condition     = fortios_firewall_policy.this.nat64 == "disable" && fortios_firewall_policy.this.ssl_ssh_profile == "SSL-Monitor"
    error_message = "A null input must give the module default."
  }
}

run "interfaces_are_required" {
  command = plan

  variables {
    srcintf = []
    dstintf = []
  }

  expect_failures = [
    var.srcintf,
    var.dstintf,
  ]
}
