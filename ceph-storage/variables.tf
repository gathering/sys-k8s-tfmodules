variable "cluster_name" {
  description = "Kubernetes cluster the storage is for. Prefix of every pool, the filesystem and the cephx clients. Changing it replaces them all, with their data"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9A-Za-z_-]+$", var.cluster_name))
    error_message = "cluster_name may only contain letters, digits, hyphens and underscores."
  }
}

variable "size" {
  description = "Number of replicas of every pool"
  type        = number
  default     = 3
  nullable    = false

  validation {
    condition     = var.size >= 1 && floor(var.size) == var.size
    error_message = "size must be a whole number, 1 or greater."
  }
}

variable "min_size" {
  description = "Fewest replicas a pool still serves I/O with. At most `size`"
  type        = number
  default     = 2
  nullable    = false

  validation {
    condition     = var.min_size >= 1 && floor(var.min_size) == var.min_size
    error_message = "min_size must be a whole number, 1 or greater."
  }
}
