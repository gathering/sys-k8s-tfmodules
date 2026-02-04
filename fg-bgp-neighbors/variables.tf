variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}

variable "neighbors" {
  description = "List of nodes"
  type = list(object({
    name = string
    ip   = string
  }))
}

# Default Variables
variable "remote_as" {
  description = "Remote AS Number"
  type        = number
  default     = 64513
}

variable "prefixes" {
  description = "Allowed prefixes"
  type = list(object({
    prefix = string
    ge     = number
  }))
  default = []
}
