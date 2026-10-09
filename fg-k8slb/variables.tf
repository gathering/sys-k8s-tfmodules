variable "cluster_name" {
  description = "Cluster name. Prefix of the VIP and policy names"
  type        = string
  nullable    = false
}

variable "extip" {
  description = "External IPv6 address"
  type        = string
  nullable    = false
}

variable "realservers_by_key" {
  description = "Control-plane nodes by a key known at plan time, each with an explicit realserver `id` and its address (IPv6). At least one. Adding or removing a node leaves the others untouched"
  type = map(object({
    id = number
    ip = string
  }))
  nullable = false

  validation {
    condition     = length(var.realservers_by_key) > 0
    error_message = "realservers_by_key must not be empty: the VIPs would have no realserver."
  }

  validation {
    condition     = alltrue([for rs in values(var.realservers_by_key) : rs.id >= 1 && floor(rs.id) == rs.id])
    error_message = "Every realserver id must be a whole number, 1 or greater."
  }

  validation {
    condition     = length(distinct(values(var.realservers_by_key)[*].id)) == length(var.realservers_by_key)
    error_message = "Realserver ids must be unique."
  }
}

variable "dstintf" {
  description = "Dst interfaces for policy"
  type        = list(string)
  nullable    = false
}

variable "srcintf" {
  description = "Src interfaces for policy"
  type        = list(string)
  nullable    = false
}

variable "srcaddr6" {
  description = "Src addresses for policy. Must exist as a address or group"
  type        = list(string)
  nullable    = false
}

variable "monitor" {
  description = "Health monitor name for VIP realservers"
  type        = string
  default     = "tcp-check"
  nullable    = false
}

variable "ssl_ssh_profile" {
  description = "SSL/SSH inspection profile for the policy"
  type        = string
  default     = "SSL-Monitor"
  nullable    = false
}
