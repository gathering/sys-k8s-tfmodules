terraform {
  required_version = ">= 1.8"

  required_providers {
    poweradmin = {
      source  = "poweradmin/poweradmin"
      version = "~> 0.6.3"
    }
  }
}
