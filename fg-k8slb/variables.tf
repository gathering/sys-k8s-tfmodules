variable "cluster_name" {
  description = "Cluster name. Prefix of the VIP and policy names"
  type        = string
}

variable "extip" {
  description = "External IPv6 address"
  type        = string
}

variable "realservers" {
  description = "Control-plane node addresses (IPv6). Each gets its position in the sorted list as realserver id, so a change of membership renumbers the ones after it. Set this or `realservers_by_key`"
  type        = list(string)
  default     = null
}

variable "realservers_by_key" {
  description = "Control-plane nodes by a key known at plan time, each with an explicit realserver `id` and its address (IPv6). Adding or removing a node leaves the others untouched. Set this or `realservers`"
  type = map(object({
    id = number
    ip = string
  }))
  default = null

  validation {
    condition     = var.realservers_by_key == null ? true : alltrue([for rs in values(var.realservers_by_key) : rs.id >= 1 && floor(rs.id) == rs.id])
    error_message = "Every realserver id must be a whole number, 1 or greater."
  }

  validation {
    condition     = var.realservers_by_key == null ? true : length(distinct(values(var.realservers_by_key)[*].id)) == length(var.realservers_by_key)
    error_message = "Realserver ids must be unique."
  }
}

variable "dstintf" {
  description = "Dst interfaces for policy"
  type        = list(string)
}

variable "srcintf" {
  description = "Src interfaces for policy"
  type        = list(string)
}

variable "srcaddr6" {
  description = "Src addresses for policy. Must exist as a address or group"
  type        = list(string)
}

variable "monitor" {
  description = "Health monitor name for VIP realservers"
  type        = string
  default     = "tcp-check"
}

variable "ssl_ssh_profile" {
  description = "SSL/SSH inspection profile for the policy"
  type        = string
  default     = "SSL-Monitor"
}
