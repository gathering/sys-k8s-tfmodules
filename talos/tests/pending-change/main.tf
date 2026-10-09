# Calls the module with an input that comes from a resource with a change pending, for
# pending_change.tftest.hcl. The value itself is known at plan time.
terraform {
  required_version = ">= 1.8"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.12.0"
    }
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

resource "terraform_data" "cluster_ip" {
  input = "2001:db8::1"
}

module "pool" {
  source = "../.."

  cluster_name          = "test"
  node_prefix           = "test-w-"
  type                  = "worker"
  node_keys             = ["a"]
  cluster_ip            = terraform_data.cluster_ip.input
  talos_version         = "v1.11.0"
  kubernetes_version    = "1.34.0"
  netbox_node_prefix    = "2001:db8:0:1::/64"
  netbox_node_prefix_id = 42
  node_vlan_vid         = 100
  netbox_site_id        = 1
  pod_subnets           = ["2001:db8:42::/56"]
  service_subnets       = ["2001:db8:42:100::/112"]
  proxmox_nodes         = ["pve1"]

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

output "machine_configuration_known" {
  description = "True when the machine config is known. Unknown during a plan, the test sees null"
  value       = nonsensitive(module.pool.machine_configuration != "")
}
