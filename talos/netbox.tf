data "netbox_cluster" "this" {
  name = var.netbox_cluster
}

data "netbox_device_role" "this" {
  name = var.netbox_device_role
}
