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

variable "domain_name" {
  description = "DNS domain. The gateway address is named `gw.<name>.<domain_name>` in Netbox"
  type        = string
  default     = "gathering.systems"
  nullable    = false
}
