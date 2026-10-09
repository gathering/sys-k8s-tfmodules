locals {
  description = var.description != null ? var.description : "Talos ${var.type} node of Kubernetes cluster ${var.cluster_name}. Managed by OpenTofu: changes made here are overwritten."

  # Hosts that get the snippet. VMs can migrate, so that is every host unless pinned
  proxmox_nodes = var.proxmox_nodes != null ? var.proxmox_nodes : data.proxmox_virtual_environment_nodes.available_nodes[0].names

  # Hosts new VMs are created on. Existing VMs never move: node_name is under ignore_changes
  placement_nodes = var.proxmox_nodes == null && var.proxmox_online_only ? [
    for i, name in local.proxmox_nodes : name if data.proxmox_virtual_environment_nodes.available_nodes[0].online[i]
  ] : local.proxmox_nodes

  # Named per pool: pools of the same type in one cluster would otherwise share the file
  snippet_file_name = "${var.cluster_name}-${var.type}-${var.node_prefix}.yaml"
}

# Not read when the hosts are pinned, so the snippet for_each keys never depend on it
data "proxmox_virtual_environment_nodes" "available_nodes" {
  count = var.proxmox_nodes == null ? 1 : 0
}

# Not uploaded for an empty pool: the machine config holds the cluster secrets
resource "proxmox_virtual_environment_file" "this" {
  for_each = toset(length(var.node_keys) > 0 ? local.proxmox_nodes : [])

  content_type = "snippets"
  datastore_id = var.snippet_datastore
  node_name    = each.value

  source_raw {
    data      = data.talos_machine_configuration.this.machine_configuration
    file_name = local.snippet_file_name
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  for_each = toset(var.node_keys)

  name        = netbox_virtual_machine.this[each.key].name
  description = local.description
  tags        = var.tags
  # By position in node_keys when the VM is created
  node_name       = element(local.placement_nodes, local.key_index[each.key])
  started         = true
  on_boot         = var.on_boot
  stop_on_destroy = true

  clone {
    vm_id        = var.template_vm_id
    node_name    = var.template_node_name
    datastore_id = var.datastore
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }

  agent {
    enabled = var.agent_enabled
    timeout = "2m"
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.disk
    iothread     = true
  }

  initialization {
    # Talos Machine config
    user_data_file_id = proxmox_virtual_environment_file.this[element(local.placement_nodes, local.key_index[each.key])].id

    datastore_id = var.datastore
    interface    = "ide1"

    dns {
      domain  = var.domain_name
      servers = var.nameservers
    }

    ip_config {
      ipv6 {
        address = netbox_available_ip_address.this[each.key].ip_address
        gateway = local.gateway
      }
    }
  }

  network_device {
    bridge  = var.vm_bridge
    vlan_id = var.node_vlan_vid
  }

  # The machine config snippet is shared by the whole pool, so the hostname cannot be in it.
  # Talos reads it from the SMBIOS serial number instead (nocloud convention: h=<hostname>).
  smbios {
    serial = "h=${netbox_virtual_machine.this[each.key].name}"
  }

  lifecycle {
    ignore_changes = [
      node_name,
      started,
      initialization
    ]

    precondition {
      condition     = length(local.placement_nodes) > 0
      error_message = "No Proxmox host to place VMs on: proxmox_online_only is set and no host is online."
    }
  }
}
