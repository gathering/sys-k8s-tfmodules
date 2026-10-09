variable "cluster_name" {
  description = "Cluster Name"
  type        = string
  nullable    = false
}

variable "neighbors_by_key" {
  description = "Nodes as a map. The keys must be known at plan time, so node names from `talos` pools can be keys and addresses cannot. Adding or removing a node leaves the other neighbors untouched"
  type = map(object({
    name = string
    ip   = string
  }))
  nullable = false
}

variable "prefixes" {
  description = "Allowed prefixes, at least one. `ge` and `le` bound the accepted prefix length; without them only the exact prefix matches. `id` is the rule id in the prefix list: set it on every entry or on none. Without ids the position in the list is used, so removing an entry renumbers the ones after it"
  type = list(object({
    prefix = string
    ge     = optional(number)
    le     = optional(number)
    id     = optional(number)
  }))
  nullable = false

  validation {
    condition     = length(var.prefixes) > 0
    error_message = "prefixes must not be empty: an inbound prefix list without rules rejects every route from the cluster."
  }

  validation {
    condition     = length(distinct([for p in var.prefixes : p.id == null])) <= 1
    error_message = "Set id on every prefixes entry or on none."
  }

  validation {
    condition     = length(distinct([for p in var.prefixes : p.id if p.id != null])) == length([for p in var.prefixes : p.id if p.id != null])
    error_message = "The ids in prefixes must be unique."
  }

  validation {
    condition     = alltrue([for p in var.prefixes : p.id == null ? true : p.id >= 1 && floor(p.id) == p.id])
    error_message = "Every id in prefixes must be a whole number, 1 or greater."
  }
}

# Default Variables
variable "remote_as" {
  description = "Remote AS Number"
  type        = string
  default     = "64513"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?$", var.remote_as))
    error_message = "remote_as must be an AS number, for example \"64513\"."
  }
}

variable "prefix_list_name" {
  description = "Name prefix of the two prefix lists, `<prefix_list_name>-in` and `-out`. Defaults to `cluster_name`. Set it on a second instance of this module for the same cluster, whose lists would otherwise collide"
  type        = string
  default     = null
}
