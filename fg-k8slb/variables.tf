variable "name" {
  description = "Name of LoadBalancer"
  type        = string
}

variable "extip" {
  description = "External IPv6 address"
  type        = string
}

variable "realservers" {
  description = "List of controlplane nodes (IPv6)"
  type        = list(string)
}

variable "dstintf" {
  description = "Dst interface for policy"
  type        = string
}

variable "srcintf" {
  description = "Src interfaces for policy"
  type        = list(string)
}

variable "srcaddr6" {
  description = "Src addresses for policy. Must exist as a address or group"
  type        = list(string)
}
