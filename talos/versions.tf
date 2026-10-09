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
