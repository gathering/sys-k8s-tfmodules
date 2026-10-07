# Generates real Talos secrets for config.tftest.hcl: rendering parses the certificates.
# Nothing here needs network access or credentials.
terraform {
  required_version = ">= 1.8"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.12.0"
    }
    # Not used here. Without them the mock_provider blocks of the test file resolve to
    # hashicorp/netbox and hashicorp/proxmox for this module
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

resource "talos_machine_secrets" "this" {}

output "machine_secrets" {
  description = "Talos machine secrets"
  sensitive   = true
  value       = talos_machine_secrets.this.machine_secrets
}

output "client_configuration" {
  description = "Talos client configuration"
  sensitive   = true
  value       = talos_machine_secrets.this.client_configuration
}
