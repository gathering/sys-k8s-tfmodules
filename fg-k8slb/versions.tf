terraform {
  required_version = ">= 1.8"

  required_providers {
    fortios = {
      source  = "fortinetdev/fortios"
      version = "~> 1.26"
    }
  }
}
