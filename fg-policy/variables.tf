variable "name" {
  description = "Name of policy"
  type        = string
  nullable    = false
}

variable "srcintf" {
  description = "Source interfaces"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.srcintf) > 0
    error_message = "srcintf must name at least one interface."
  }
}

variable "srcaddr6" {
  description = "Source IPv6 addresses"
  type        = list(string)
  nullable    = false
}

variable "dstintf" {
  description = "Destination interfaces"
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.dstintf) > 0
    error_message = "dstintf must name at least one interface."
  }
}

variable "dstaddr6" {
  description = "Destination IPv6 addresses"
  type        = list(string)
  nullable    = false
}

variable "services" {
  description = "Services"
  type        = list(string)
  nullable    = false
}

variable "nat64" {
  description = "Enable NAT64"
  type        = bool
  default     = false
  nullable    = false
}

variable "nat" {
  description = "Source NAT (`nat`) on the policy. Null leaves it unset"
  type        = bool
  default     = null
}

variable "comments" {
  description = "Policy comment. Defaults to `<name> - Created by Terraform Provider for FortiOS`"
  type        = string
  default     = null
}

variable "nat64_pool" {
  description = "IP pool used when `nat64` is true"
  type        = string
  default     = "NAT64-POOL"
  nullable    = false
}

variable "ssl_ssh_profile" {
  description = "SSL/SSH inspection profile"
  type        = string
  default     = "SSL-Monitor"
  nullable    = false
}
