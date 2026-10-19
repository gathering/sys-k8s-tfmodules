terraform {
  required_version = ">= 1.8"

  required_providers {
    ceph = {
      source  = "gathering/ceph"
      version = "0.2.0"
    }
  }
}
