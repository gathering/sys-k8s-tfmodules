locals {
  nat   = var.nat == true
  nat64 = var.nat64 == true
}

resource "fortios_firewall_policy" "this" {
  action           = "accept"
  inspection_mode  = "flow"
  internet_service = "disable"
  logtraffic       = "all"
  name             = var.name
  schedule         = "always"
  ssl_ssh_profile  = var.ssl_ssh_profile
  status           = "enable"
  comments         = var.comments == null ? "${var.name} - Created by Terraform Provider for FortiOS" : var.comments == "" ? null : var.comments

  # Null leaves an argument unset, which is not the same to the provider as "disable"
  nat    = var.nat == null ? null : local.nat ? "enable" : "disable"
  nat64  = var.nat64 == null ? null : local.nat64 ? "enable" : "disable"
  ippool = var.nat64 == null ? null : local.nat64 ? "enable" : "disable"

  dynamic "poolname" {
    for_each = local.nat64 ? [var.nat64_pool] : []
    content {
      name = poolname.value
    }
  }

  dynamic "srcintf" {
    for_each = var.srcintf
    content {
      name = srcintf.value
    }
  }

  dynamic "srcaddr" {
    for_each = local.nat64 ? ["all"] : []
    content {
      name = srcaddr.value
    }
  }

  dynamic "srcaddr6" {
    for_each = var.srcaddr6
    content {
      name = srcaddr6.value
    }
  }

  dynamic "dstintf" {
    for_each = var.dstintf
    content {
      name = dstintf.value
    }
  }

  dynamic "dstaddr" {
    for_each = local.nat64 ? ["all"] : []
    content {
      name = dstaddr.value
    }
  }

  dynamic "dstaddr6" {
    for_each = var.dstaddr6
    content {
      name = dstaddr6.value
    }
  }

  dynamic "service" {
    for_each = var.services
    content {
      name = service.value
    }
  }
}
