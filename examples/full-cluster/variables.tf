variable "cluster_name" {
  description = "Cluster name. Also names the VLAN and prefixes the FortiGate objects"
  type        = string
  default     = "example"
}

variable "cluster_ip" {
  description = "IPv6 address of the API load balancer on the FortiGate"
  type        = string
  default     = "2001:db8:ffff::10"
}

variable "domain_name" {
  description = "DNS domain of the nodes, the gateway and the API name. Also the Poweradmin zone their records go in"
  type        = string
  default     = "gathering.systems"
}

variable "controlplane_nodes" {
  description = "Control planes: node key => realserver id on the load balancer. The node is named `<cluster_name>-cp-<key>`. Never give an id to another key while its node exists"
  type        = map(number)
  default     = { a = 1, b = 2, c = 3 }
}

variable "worker_keys" {
  description = "Workers: one key per node. The node is named `<cluster_name>-w-<key>`"
  type        = list(string)
  default     = ["a", "b"]
}

variable "talos_version" {
  description = "Talos version contract the machine config is generated for"
  type        = string
  default     = "v1.14.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.37.1"
}

variable "netbox_vlan_group_name" {
  description = "Netbox VLAN group the VLAN ID is allocated from"
  type        = string
  default     = "prod-vlans"
}

variable "netbox_base_prefix" {
  description = "Netbox prefix the node /64 is allocated from"
  type        = string
  default     = "2001:db8::/48"
}

variable "netbox_role_id" {
  description = "Netbox role ID for the VLAN and its prefix"
  type        = number
  default     = 5
}

variable "netbox_site_id" {
  description = "Netbox site ID of the nodes"
  type        = number
  default     = 1
}

variable "pod_subnets" {
  description = "Pod CIDRs"
  type        = list(string)
  default     = ["2001:db8:1000::/56"]
}

variable "service_subnets" {
  description = "Service CIDRs"
  type        = list(string)
  default     = ["2001:db8:1000:100::/112"]
}

variable "bgp_prefixes" {
  description = "Prefixes the cluster may announce to the FortiGate. The ids are the rule ids in the prefix list"
  type = list(object({
    prefix = string
    ge     = optional(number)
    le     = optional(number)
    id     = optional(number)
  }))
  default = [
    { id = 1, prefix = "2001:db8:2000::/56", ge = 128, le = 128 },
  ]
}

variable "proxmox_nodes" {
  description = "Proxmox hosts to place the nodes on. Null uses every host"
  type        = list(string)
  default     = null
}

variable "wan_interface" {
  description = "FortiGate interface towards the internet"
  type        = string
  default     = "wan1"
}

variable "api_source_interfaces" {
  description = "FortiGate interfaces the Kubernetes and Talos APIs are reached from"
  type        = list(string)
  default     = ["Infra"]
}

variable "api_source_addresses" {
  description = "FortiGate address objects allowed to reach the Kubernetes and Talos APIs"
  type        = list(string)
  default     = ["bastions-v6"]
}

variable "keycloak_url" {
  description = "URL of Keycloak, without a trailing slash"
  type        = string
  default     = "https://sso.example.org"
}

variable "keycloak_realm_name" {
  description = "Keycloak realm of the cluster's OIDC client"
  type        = string
  default     = "example"
}

variable "poweradmin_url" {
  description = "URL of Poweradmin"
  type        = string
  default     = "https://dns.example.org"
}

variable "poweradmin_api_key" {
  description = "Poweradmin API key"
  type        = string
  sensitive   = true
}
