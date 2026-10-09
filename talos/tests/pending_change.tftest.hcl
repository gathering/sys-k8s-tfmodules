# The machine config must be rendered during the plan when an input comes from a resource
# with a change pending. If it is not, every snippet file is replaced and the config is
# applied again on every node, although nothing in it changed. A precondition or
# postcondition on data.talos_machine_configuration.this breaks this.

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

run "config_is_known_with_a_change_pending_upstream" {
  command = plan

  module {
    source = "./tests/pending-change"
  }

  assert {
    condition     = output.machine_configuration_known == true
    error_message = "The machine config must be known at plan time when an input comes from a resource with a change pending."
  }
}
