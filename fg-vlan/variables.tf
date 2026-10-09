variable "name" {
  description = "Name of new vlan. Also used as the FortiGate interface alias, which is limited to 25 characters"
  type        = string
  nullable    = false

  validation {
    condition     = length(var.name) <= 25
    error_message = "name must be at most 25 characters: it becomes the FortiGate interface alias."
  }
}

variable "netbox_vlan_group_name" {
  description = "Name of the Netbox VLAN group the VLAN ID is allocated from"
  type        = string
  nullable    = false
}

variable "netbox_role_id" {
  description = "Netbox ID of the role set on the VLAN and the prefix"
  type        = number
  nullable    = false
}

variable "netbox_base_prefix" {
  description = "Netbox prefix, in CIDR notation, the VLAN prefix is allocated from"
  type        = string
  nullable    = false
}

variable "interface" {
  description = "Interface on fortigate to add vlan to"
  type        = string
  default     = "fg-bond"
  nullable    = false
}

variable "prefix_length" {
  description = "Prefix Length"
  type        = number
  default     = 64
  nullable    = false
}

variable "vdom" {
  description = "Fortigate VDOM"
  type        = string
  default     = "root"
  nullable    = false
}

# Nullable on purpose: null leaves the gateway without a DNS name
variable "domain_name" {
  description = "DNS domain. The gateway address is named `gw.<name>.<domain_name>` in Netbox, so `name` must then be usable in a DNS name. Null leaves the gateway address without a DNS name"
  type        = string
  default     = "gathering.systems"

  validation {
    condition     = var.domain_name == null ? true : can(regex("^[0-9A-Za-z_-]+(\\.[0-9A-Za-z_-]+)*$", var.domain_name))
    error_message = "domain_name must be a DNS domain: labels of letters, digits, hyphens and underscores, separated by dots. Or null for no DNS name."
  }
}
