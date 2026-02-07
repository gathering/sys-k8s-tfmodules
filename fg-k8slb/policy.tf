resource "fortios_firewall_policy" "this" {
  action           = "accept"
  inspection_mode  = "flow"
  internet_service = "disable"
  logtraffic       = "all"
  name             = "${var.name}-in"
  schedule         = "always"
  ssl_ssh_profile  = "SSL-Monitor" # Hardcoded
  status           = "enable"
  nat              = "disable"

  dstintf {
    name = var.dstintf
  }

  dstaddr6 {
    name = fortios_firewall_vip6.k8s_api.name
  }

  dstaddr6 {
    name = fortios_firewall_vip6.talos_control_api.name
  }

  dstaddr6 {
    name = fortios_firewall_vip6.talosctl_api.name
  }

  dynamic "srcintf" {
    for_each = var.srcintf
    content {
      name = srcintf.value
    }
  }

  dynamic "srcaddr6" {
    for_each = var.srcaddr6
    content {
      name = srcaddr6.value
    }
  }

  service {
    name = "ALL"
  }
}
