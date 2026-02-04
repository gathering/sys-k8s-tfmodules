variable "name" {
  description = "Name of policy"
  type        = string
}

variable "srcintf" {
  description = "Name of policy"
  type        = string
}

variable "srcaddr6" {
  description = "Name of policy"
  type        = list(string)
}

variable "dstintf" {
  description = "Name of policy"
  type        = string
}

variable "dstaddr6" {
  description = "Name of policy"
  type        = list(string)
}

variable "services" {
  description = "Name of policy"
  type        = list(string)
}

variable "nat64" {
  description = "Enable NAT64"
  type        = bool
  default     = false
}
