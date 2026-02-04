variable "name" {
  description = "Name of new vlan"
  type        = string
}

variable "vlan_group" {
  description = "VLAN group name"
  type        = string
}

variable "netbox_role_id" {
  description = "Netbox Role ID"
  type        = number
}

variable "base_prefix" {
  description = "Base Prefix used to get new vlan prefix"
  type        = string
}

variable "infra_zone" {
  description = "Fortigate zone where bastions are located"
  type        = string
  default     = "Infra"
}

variable "bastion_address_group" {
  description = "IP to bastion hosts to access this vlan"
  type        = string
  default     = "bastions-v6"
}

variable "interface" {
  description = "Inteface on fortigate to add vlan to"
  type        = string
  default     = "fg-bond"
}

variable "prefix_length" {
  description = "Prefix Length"
  type        = number
  default     = 64
}

variable "vdom" {
  description = "Fortigate VDOM"
  type        = string
  default     = "root"
}

