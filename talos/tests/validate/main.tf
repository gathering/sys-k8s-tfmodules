# Runs `talosctl validate` on a machine config that a run of config.tftest.hcl rendered.
# The talos provider renders a config without validating it: a patch that Talos rejects
# on the node renders fine. Needs talosctl on the PATH.
terraform {
  required_version = ">= 1.8"

  # Not used here. Without them the mock_provider blocks of the test file resolve to
  # hashicorp/netbox and hashicorp/proxmox for this module
  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 5.8"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.116.0"
    }
  }
}

variable "machine_configuration" {
  description = "Rendered machine config, the machine_configuration output of a run"
  type        = string
  sensitive   = true
}

resource "terraform_data" "validate" {
  # The config holds the test secrets of the setup module only. Left sensitive, it would
  # hide what talosctl prints, which is the reason the validation failed
  input = nonsensitive(var.machine_configuration)

  # The validate runs share one state. A provisioner only runs on create, so a new config
  # has to replace the resource, or the second run would validate nothing
  triggers_replace = nonsensitive(var.machine_configuration)

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = "file=$(mktemp) && printf '%s' \"$MACHINE_CONFIGURATION\" > \"$file\" && talosctl validate --mode metal --strict --config \"$file\"; status=$?; rm -f \"$file\"; exit $status"

    environment = {
      MACHINE_CONFIGURATION = self.input
    }
  }
}
