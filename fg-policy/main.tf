resource "fortios_firewall_policy" "this" {
  action           = "accept"
  inspection_mode  = "flow"
  internet_service = "disable"
  logtraffic       = "all"
  name             = var.name
  schedule         = "always"
  ssl_ssh_profile  = "SSL-Monitor" # Hardcoded
  status           = "enable"
  comments         = "${var.name} - Created by Terraform Provider for FortiOS"

  nat64  = var.nat64 ? "enable" : "disable"
  ippool = var.nat64 ? "enable" : "disable"

  dynamic "poolname" {
    for_each = var.nat64 ? ["NAT64-POOL"] : []
    content {
      name = poolname.value
    }
  }

  srcintf {
    name = var.srcintf
  }

  dynamic "srcaddr" {
    for_each = var.nat64 ? ["all"] : []
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

  dstintf {
    name = var.dstintf
  }

  dynamic "dstaddr" {
    for_each = var.nat64 ? ["all"] : []
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
