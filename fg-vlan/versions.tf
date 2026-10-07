terraform {
  required_version = ">= 1.8"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 5.8"
    }
    fortios = {
      source  = "fortinetdev/fortios"
      version = "~> 1.26"
    }
  }
}
