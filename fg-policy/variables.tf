variable "name" {
  description = "Name of policy"
  type        = string
}

variable "srcintf" {
  description = "Source interfaces"
  type        = list(string)

  validation {
    condition     = length(var.srcintf) > 0
    error_message = "srcintf must name at least one interface."
  }
}

variable "srcaddr6" {
  description = "Source IPv6 addresses"
  type        = list(string)
}

variable "dstintf" {
  description = "Destination interfaces"
  type        = list(string)

  validation {
    condition     = length(var.dstintf) > 0
    error_message = "dstintf must name at least one interface."
  }
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
  description = "Enable NAT64. Null leaves `nat64` and `ippool` unset on the policy instead of setting them to `disable`"
  type        = bool
  default     = false
}

variable "nat" {
  description = "Source NAT (`nat`) on the policy. Null leaves it unset"
  type        = bool
  default     = null
}

variable "comments" {
  description = "Policy comment. Null gives `<name> - Created by Terraform Provider for FortiOS`. An empty string leaves the comment unset: nothing is sent, so a comment that exists on the device is not cleared"
  type        = string
  default     = null
}

variable "nat64_pool" {
  description = "IP pool used when `nat64` is true"
  type        = string
  default     = "NAT64-POOL"
}

variable "ssl_ssh_profile" {
  description = "SSL/SSH inspection profile"
  type        = string
  default     = "SSL-Monitor"
}
