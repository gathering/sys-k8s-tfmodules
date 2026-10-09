variable "cluster_name" {
  description = "Cluster Name"
  type        = string
  nullable    = false

  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "cluster_name must not be empty."
  }
}

variable "node_prefix" {
  description = "Prefix for node name. The node's key is appended to form the hostname. Also part of the machine config snippet name, so it must differ between the pools of a cluster"
  type        = string
  nullable    = false

  # Looser than the Proxmox `dns-name` format the VM name has to match. Not empty: the
  # snippet is named after it
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*$", var.node_prefix))
    error_message = "node_prefix must not be empty, may only contain letters, digits, hyphens and dots, and must start with a letter or digit: Proxmox rejects any other VM name."
  }
}

variable "type" {
  description = "worker or controlplane"
  type        = string
  nullable    = false

  validation {
    condition     = contains(["controlplane", "worker"], var.type)
    error_message = "type must be \"controlplane\" or \"worker\"."
  }
}

variable "node_keys" {
  description = "One key per node, known at plan time. Each node is named `<node_prefix><key>` and tracked by its key, so any node can be removed without touching the others. Only a worker pool may be empty"
  type        = list(string)
  nullable    = false

  validation {
    condition     = alltrue([for key in var.node_keys : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", key))])
    error_message = "A node key may only contain lowercase letters, digits and hyphens, and must start and end with a letter or digit: it is part of the hostname."
  }

  validation {
    condition     = length(distinct(var.node_keys)) == length(var.node_keys)
    error_message = "node_keys must not contain duplicates."
  }
}

variable "cores" {
  description = "Number of CPU Cores per node"
  type        = number
  default     = 2
  nullable    = false
}

variable "memory" {
  description = "Memory size per node (MB)"
  type        = number
  default     = 4096
  nullable    = false
}

variable "disk" {
  description = "Disk size (OS) per node (GB)"
  type        = number
  default     = 24
  nullable    = false
}

variable "netbox_node_prefix" {
  description = "Node IPv6 prefix in CIDR notation. Host 1 of it is the default `gateway`. Must be the prefix `netbox_node_prefix_id` refers to"
  type        = string
  nullable    = false
}

variable "netbox_node_prefix_id" {
  description = "Netbox ID of the node prefix. Node addresses are allocated from it. Required unless `netbox_node_prefix_lookup` is true"
  type        = number
  default     = null
}

variable "netbox_node_prefix_lookup" {
  description = "Look up the Netbox ID of `netbox_node_prefix` instead of taking it from `netbox_node_prefix_id`. Only for a prefix that exists before the plan, see the README"
  type        = bool
  default     = false
  nullable    = false
}

variable "gateway" {
  description = "IPv6 default gateway of the nodes. Defaults to host 1 of `netbox_node_prefix`"
  type        = string
  default     = null
}

variable "node_vlan_vid" {
  description = "VLAN to place nodes"
  type        = number
  nullable    = false
}

variable "netbox_site_id" {
  description = "Netbox ID of the site the VMs are registered in"
  type        = number
  nullable    = false
}

variable "netbox_cluster_name" {
  description = "Name of the Netbox cluster the VMs are registered in"
  type        = string
  default     = "pve"
  nullable    = false
}

variable "netbox_device_role_name" {
  description = "Name of the Netbox device role of the VMs"
  type        = string
  default     = "Server"
  nullable    = false
}

variable "device_networkcard_name" {
  description = "Netbox nic name"
  type        = string
  default     = "eth0"
  nullable    = false
}

# Marking this sensitive plans no change: the rendered machine config it feeds is
# already sensitive in the provider.
variable "talos_machine_secrets" {
  description = "Talos machine secrets, the `machine_secrets` attribute of a `talos_machine_secrets` resource"
  type = object({
    certs = object({
      etcd               = object({ cert = string, key = string })
      k8s                = object({ cert = string, key = string })
      k8s_aggregator     = object({ cert = string, key = string })
      k8s_serviceaccount = object({ key = string })
      os                 = object({ cert = string, key = string })
    })
    cluster = object({ id = string, secret = string })
    secrets = object({
      bootstrap_token             = string
      secretbox_encryption_secret = string
      aescbc_encryption_secret    = optional(string)
    })
    trustdinfo = object({ token = string })
  })
  sensitive = true
  nullable  = false
}

# Not marked sensitive: that would mark the whole object on the talos resources. The
# provider already treats client_key as sensitive.
variable "talos_client_configuration" {
  description = "Talos client configuration, the `client_configuration` attribute of a `talos_machine_secrets` resource"
  type = object({
    ca_certificate     = string
    client_certificate = string
    client_key         = string
  })
  nullable = false
}

variable "cluster_ip" {
  description = "IPv6 LB IP to cluster"
  type        = string
  nullable    = false
}

variable "cpu_type" {
  description = "Proxmox CPU Type"
  type        = string
  default     = "Skylake-Server-noTSX-IBRS"
  nullable    = false
}

variable "pod_subnets" {
  description = "k8s pod subnets in CIDR notation, at least one"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.pod_subnets) > 0 && alltrue([for s in var.pod_subnets : can(cidrhost(s, 0))])
    error_message = "pod_subnets must be a non-empty list of CIDR prefixes: Talos replaces its own default with this list."
  }
}

variable "service_subnets" {
  description = "k8s service subnets in CIDR notation, at least one"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.service_subnets) > 0 && alltrue([for s in var.service_subnets : can(cidrhost(s, 0))])
    error_message = "service_subnets must be a non-empty list of CIDR prefixes: Talos replaces its own default with this list."
  }
}

variable "nameservers" {
  description = "DNS Servers. Use DNS64 if this is a IPv6 only cluster"
  type        = list(string)
  default     = ["2606:4700:4700::64"]
  nullable    = false
}

variable "datastore" {
  description = "Proxmox Datastore"
  type        = string
  default     = "ceph1"
  nullable    = false
}

variable "snippet_datastore" {
  description = "Proxmox datastore the machine config snippet is uploaded to on every host. Must allow the `snippets` content type"
  type        = string
  default     = "local"
  nullable    = false
}

variable "template_vm_id" {
  description = "VM ID of the Talos template to clone"
  type        = number
  default     = 9201
  nullable    = false
}

variable "template_node_name" {
  description = "Proxmox host the template is on"
  type        = string
  default     = "pve1"
  nullable    = false
}

variable "proxmox_nodes" {
  description = "Proxmox hosts to use, in placement order: the snippet is uploaded to each and node N of `node_keys` is created on host N, wrapping around. Defaults to every host the API returns, in API order"
  type        = list(string)
  default     = null

  validation {
    condition     = var.proxmox_nodes == null ? true : length(var.proxmox_nodes) > 0
    error_message = "proxmox_nodes must name at least one host, or be null to use every host."
  }

  validation {
    condition     = var.proxmox_nodes == null ? true : length(distinct(var.proxmox_nodes)) == length(var.proxmox_nodes)
    error_message = "proxmox_nodes must not contain duplicates."
  }
}

variable "proxmox_online_only" {
  description = "Create new VMs on online hosts only. The snippet still goes to every host. Ignored when `proxmox_nodes` is set"
  type        = bool
  default     = false
  nullable    = false
}

variable "on_boot" {
  description = "Start the VMs when their Proxmox host boots"
  type        = bool
  default     = false
  nullable    = false
}

variable "agent_enabled" {
  description = "Enable the QEMU guest agent. The template needs the qemu-guest-agent extension, otherwise every VM create waits for the agent timeout"
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "Proxmox VM tags"
  type        = list(string)
  default     = ["kubernetes", "terraform"]
  nullable    = false
}

variable "description" {
  description = "Proxmox VM description. Defaults to a text naming the cluster, the node type and that the VM is managed by OpenTofu"
  type        = string
  default     = null
}

variable "vm_bridge" {
  description = "Proxmox Network Bridge"
  type        = string
  default     = "vmbr0"
  nullable    = false
}

variable "domain_name" {
  description = "DNS domain of the nodes: the search domain of the VMs, and the domain of each node's DNS name in Netbox (`<node_prefix><key>.<domain_name>`)"
  type        = string
  default     = "gathering.systems"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9A-Za-z_-]+(\\.[0-9A-Za-z_-]+)*$", var.domain_name))
    error_message = "domain_name must be a DNS domain: labels of letters, digits, hyphens and underscores, separated by dots."
  }
}

variable "time_servers" {
  description = "List of time_servers"
  type        = list(string)
  default     = ["time.cloudflare.com"]
  nullable    = false
}

variable "talos_version" {
  description = "Talos version contract the machine config is generated for, v1.14 or later. It does not select the installed Talos image. The nodes must run at least this version"
  type        = string
  default     = "v1.14.2"
  nullable    = false

  validation {
    condition     = can(regex("^v?(1\\.(1[4-9]|[2-9][0-9])|[2-9])\\.", var.talos_version))
    error_message = "talos_version must be v1.14 or later: the config is built from the configuration documents of Talos 1.14."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.35.5"
  nullable    = false
}

variable "apply_mode" {
  description = "How config changes are applied to existing nodes: `auto`, `reboot`, `no_reboot`, `staged` or `staged_if_needing_reboot`. The default stages a change that needs a reboot instead of rebooting the node, see the README"
  type        = string
  default     = "staged_if_needing_reboot"
  nullable    = false

  validation {
    condition     = contains(["auto", "reboot", "no_reboot", "staged", "staged_if_needing_reboot"], var.apply_mode)
    error_message = "apply_mode must be one of auto, reboot, no_reboot, staged, staged_if_needing_reboot."
  }
}

variable "on_destroy" {
  description = "What happens to a node when it is removed from the pool. By default the VM is deleted without telling Talos. `{ reset = true }` resets the node first, which makes a control plane leave etcd; the node must be reachable for that. A change only takes effect once applied, see the README"
  type = object({
    graceful = optional(bool, true)
    reset    = optional(bool, false)
    reboot   = optional(bool, false)
  })
  default  = {}
  nullable = false
}

variable "talos_inline_manifests" {
  description = "Talos Inline Manifests. Only applied through control planes"
  type = list(object({
    name     = string
    contents = string
  }))
  default  = []
  nullable = false
}

variable "allow_scheduling_on_control_planes" {
  description = "Allow scheduling on control planes"
  type        = bool
  default     = false
  nullable    = false
}

variable "oidc" {
  description = "OIDC for kube-apiserver, set up in an AuthenticationConfiguration file: needs Kubernetes 1.34 or later. Null leaves OIDC off. Tokens are accepted for `client_id` and for each of `audiences`. Set `groups_claim` to `\"\"` to give the users no groups, and a prefix to `\"\"` for no prefix. `groups_prefix` is also put in front of the group in the cluster-admin binding"
  type = object({
    issuer_url      = string
    client_id       = string
    audiences       = optional(list(string), [])
    username_claim  = optional(string, "preferred_username")
    username_prefix = optional(string, "oidc:")
    groups_claim    = optional(string, "groups")
    groups_prefix   = optional(string, "oidc:")
  })
  default = null

  validation {
    condition     = var.oidc == null ? true : alltrue([for v in [var.oidc.issuer_url, var.oidc.client_id, var.oidc.username_claim] : v != null && v != ""])
    error_message = "oidc needs issuer_url, client_id and username_claim: kube-apiserver does not start without them. Set oidc to null to turn OIDC off."
  }

  validation {
    condition     = var.oidc == null ? true : alltrue([for v in var.oidc.audiences : v != null && v != ""])
    error_message = "oidc.audiences must not have an empty entry."
  }
}

variable "discovery_enabled" {
  description = "Enable Talos Discovery"
  type        = bool
  default     = true
  nullable    = false
}

variable "discovery_service_endpoint" {
  description = "Discovery Service Endpoint"
  type        = string
  default     = "https://discovery.talos.dev:443"
  nullable    = false
}
