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
    name = "k8s-infra"
  }

  srcaddr6 {
    name = "bastions-v6"
  }

  srcaddr6 {
    name = "vlan1700 address"
  }

  srcaddr6 {
    name = "vlan1701 address"
  }

  srcaddr6 {
    name = "vlan1702 address"
  }

  srcintf {
    name = "Infra"
  }

  srcintf {
    name = "k8s-infra"
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

  service {
    name = "ALL"
  }
}
