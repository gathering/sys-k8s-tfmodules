variable "name" {
  description = "Name of policy"
  type        = string
}

variable "srcintf" {
  description = "Source interface"
  type        = string
}

variable "srcaddr6" {
  description = "Source IPv6 addresses"
  type        = list(string)
}

variable "dstintf" {
  description = "Destination interface"
  type        = string
}

variable "dstaddr6" {
  description = "Destination IPv6 addresses"
  type        = list(string)
}

variable "services" {
  description = "Services"
  type        = list(string)
}

variable "nat64" {
  description = "Enable NAT64"
  type        = bool
  default     = false
}
