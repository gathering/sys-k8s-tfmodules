# Gateway, interface and outputs, with both providers mocked.

mock_provider "netbox" {
  mock_data "netbox_vlan_group" {
    defaults = {
      id = "3"
    }
  }

  mock_data "netbox_prefix" {
    defaults = {
      id = 40
    }
  }

  mock_resource "netbox_available_vlan" {
    defaults = {
      id  = "50"
      vid = 123
    }
  }

  mock_resource "netbox_available_prefix" {
    defaults = {
      id     = "60"
      prefix = "2001:db8:0:7b::/64"
    }
  }
}

mock_provider "fortios" {}

variables {
  name                   = "test"
  netbox_vlan_group_name = "prod-vlans"
  netbox_role_id         = 5
  netbox_base_prefix     = "2001:db8::/48"
}

run "vlan" {
  assert {
    condition     = data.netbox_vlan_group.this.name == "prod-vlans" && data.netbox_prefix.this.prefix == "2001:db8::/48"
    error_message = "The VLAN group and the base prefix must be looked up by the given name and prefix."
  }

  assert {
    condition     = netbox_ip_address.gw.ip_address == "2001:db8:0:7b::1/64" && fortios_system_interface.this.ipv6[0].ip6_address == "2001:db8:0:7b::1/64"
    error_message = "The gateway must be host 1 of the allocated prefix, in Netbox and on the interface."
  }

  assert {
    condition     = netbox_ip_address.gw.dns_name == "gw.test.gathering.systems"
    error_message = "The gateway address must get the DNS name gw.<name>.<domain_name>."
  }

  assert {
    condition     = fortios_system_interface.this.description == "test (VLAN 123). Managed by OpenTofu" && fortios_firewall_address6.this.comment == "Prefix of test (VLAN 123). Managed by OpenTofu"
    error_message = "Interface and address must say which VLAN they belong to."
  }

  assert {
    condition     = fortios_system_interface.this.name == "vlan123" && fortios_system_interface.this.vlanid == 123 && fortios_system_interface.this.alias == "test"
    error_message = "The interface must be named vlan<VLAN ID>, with the VLAN name as alias."
  }

  assert {
    condition = alltrue([
      output.netbox_vlan_name == "test",
      output.interface_name == "vlan123",
      output.vlan_vid == 123,
      output.prefix == "2001:db8:0:7b::/64",
      output.prefix_id == "60",
      output.firewall_address_name == "vlan123 address",
    ])
    error_message = "An output no longer carries the value its name says."
  }
}

run "null_gives_the_default" {
  command = plan

  variables {
    interface     = null
    prefix_length = null
    vdom          = null
  }

  assert {
    condition     = fortios_system_interface.this.interface == "fg-bond" && fortios_system_interface.this.vdom == "root" && netbox_available_prefix.this.prefix_length == 64
    error_message = "A null input must give the module default."
  }
}

run "name_must_fit_the_interface_alias" {
  command = plan

  variables {
    name = "a-name-longer-than-25-chars"
  }

  expect_failures = [
    var.name,
  ]
}
