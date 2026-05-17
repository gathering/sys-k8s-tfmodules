# TG Talos (k8s) Terraform Module

Provisions a group of Talos Kubernetes nodes (controlplane or worker) on Proxmox, registers each node in Netbox with an allocated IPv6 address, and applies Talos machine configuration. When `type = "controlplane"`, also bootstraps etcd and retrieves the kubeconfig.

## Prerequisites

- A Talos machine secrets object and client configuration (created once per cluster, outside this module)
- A Netbox IPv6 prefix to allocate node IPs from
- A Proxmox template VM to clone from (currently `vm_id = 9201` on `pve1`)

## Usage

```hcl
module "controlplane" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//talos"

  cluster_name               = "my-cluster"
  node_prefix                = "cp"
  type                       = "controlplane"
  nodes                      = 3
  cluster_ip                 = "2001:db8::1"
  talos_version              = "v1.7.0"
  talos_machine_secrets      = talos_machine_secrets.this.machine_secrets
  talos_client_configuration = talos_machine_secrets.this.client_configuration
  netbox_node_prefix         = "2001:db8::/64"
  netbox_node_prefix_id      = 42
  node_vlan_vid              = 100
  netbox_site_id             = 1
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_netbox"></a> [netbox](#provider\_netbox) | n/a |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_talos"></a> [talos](#provider\_talos) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [netbox_available_ip_address.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/available_ip_address) | resource |
| [netbox_interface.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/interface) | resource |
| [netbox_primary_ip.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/primary_ip) | resource |
| [netbox_virtual_machine.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/virtual_machine) | resource |
| [proxmox_virtual_environment_file.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [random_id.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [netbox_cluster.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/data-sources/cluster) | data source |
| [netbox_device_role.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/data-sources/device_role) | data source |
| [proxmox_virtual_environment_nodes.available_nodes](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_nodes) | data source |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allow_scheduling_on_control_planes"></a> [allow\_scheduling\_on\_control\_planes](#input\_allow\_scheduling\_on\_control\_planes) | Allow scheduling on control planes | `bool` | `false` | no |
| <a name="input_cluster_ip"></a> [cluster\_ip](#input\_cluster\_ip) | IPv6 LB IP to cluster | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster Name | `string` | n/a | yes |
| <a name="input_cores"></a> [cores](#input\_cores) | Number of CPU Cores per node | `number` | `2` | no |
| <a name="input_cpu_type"></a> [cpu\_type](#input\_cpu\_type) | Proxmox CPU Type | `string` | `"Skylake-Server-noTSX-IBRS"` | no |
| <a name="input_datastore"></a> [datastore](#input\_datastore) | Proxmox Datastore | `string` | `"ceph1"` | no |
| <a name="input_device_networkcard_name"></a> [device\_networkcard\_name](#input\_device\_networkcard\_name) | Netbox nic name | `string` | `"eth0"` | no |
| <a name="input_discovery_enabled"></a> [discovery\_enabled](#input\_discovery\_enabled) | Enable Talos Discovery | `bool` | `true` | no |
| <a name="input_discovery_service_endpoint"></a> [discovery\_service\_endpoint](#input\_discovery\_service\_endpoint) | Discovery Service Endpoint | `string` | `"https://discovery.talos.dev:443"` | no |
| <a name="input_disk"></a> [disk](#input\_disk) | Disk size (OS) per node (GB) | `number` | `24` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | DNS Domain Name | `string` | `"gathering.systems"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes Version | `string` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory size per node (MB) | `number` | `4096` | no |
| <a name="input_nameservers"></a> [nameservers](#input\_nameservers) | DNS Servers. Use DNS64 if this is a IPv6 only cluster | `list(string)` | <pre>[<br/>  "2606:4700:4700::64"<br/>]</pre> | no |
| <a name="input_netbox_cluster"></a> [netbox\_cluster](#input\_netbox\_cluster) | Netbox Cluster Name | `string` | `"pve"` | no |
| <a name="input_netbox_device_role"></a> [netbox\_device\_role](#input\_netbox\_device\_role) | Netbox Device Role | `string` | `"Server"` | no |
| <a name="input_netbox_node_prefix"></a> [netbox\_node\_prefix](#input\_netbox\_node\_prefix) | Netbox IPv6 prefix for nodes | `string` | n/a | yes |
| <a name="input_netbox_node_prefix_id"></a> [netbox\_node\_prefix\_id](#input\_netbox\_node\_prefix\_id) | Netbox IPv6 prefix for nodes | `number` | n/a | yes |
| <a name="input_netbox_site_id"></a> [netbox\_site\_id](#input\_netbox\_site\_id) | Netbox Site ID | `number` | n/a | yes |
| <a name="input_node_prefix"></a> [node\_prefix](#input\_node\_prefix) | Prefix for node name | `string` | n/a | yes |
| <a name="input_node_vlan_vid"></a> [node\_vlan\_vid](#input\_node\_vlan\_vid) | VLAN to place nodes | `number` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Number of nodes to be created | `number` | `3` | no |
| <a name="input_oidc_client_id"></a> [oidc\_client\_id](#input\_oidc\_client\_id) | OIDC Client ID | `string` | `""` | no |
| <a name="input_oidc_groups_claim"></a> [oidc\_groups\_claim](#input\_oidc\_groups\_claim) | OIDC Groups Claim | `string` | `"groups"` | no |
| <a name="input_oidc_groups_prefix"></a> [oidc\_groups\_prefix](#input\_oidc\_groups\_prefix) | OIDC Groups Prefix | `string` | `"oidc:"` | no |
| <a name="input_oidc_issuer_url"></a> [oidc\_issuer\_url](#input\_oidc\_issuer\_url) | OIDC Issuer URL | `string` | `""` | no |
| <a name="input_oidc_username_claim"></a> [oidc\_username\_claim](#input\_oidc\_username\_claim) | OIDC Username Claim | `string` | `"preferred_username"` | no |
| <a name="input_oidc_username_prefix"></a> [oidc\_username\_prefix](#input\_oidc\_username\_prefix) | OIDC Username Prefix | `string` | `"oidc:"` | no |
| <a name="input_pod_subnets"></a> [pod\_subnets](#input\_pod\_subnets) | k8s pod subnets | `list` | `[]` | no |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | k8s service subnets | `list` | `[]` | no |
| <a name="input_talos_client_configuration"></a> [talos\_client\_configuration](#input\_talos\_client\_configuration) | client\_configuration | `any` | n/a | yes |
| <a name="input_talos_inline_manifests"></a> [talos\_inline\_manifests](#input\_talos\_inline\_manifests) | Talos Inline Manifests | `list` | `[]` | no |
| <a name="input_talos_machine_secrets"></a> [talos\_machine\_secrets](#input\_talos\_machine\_secrets) | talos secrets | `any` | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talosctl Version | `string` | n/a | yes |
| <a name="input_time_servers"></a> [time\_servers](#input\_time\_servers) | List of time\_servers | `list(string)` | <pre>[<br/>  "time.cloudflare.com"<br/>]</pre> | no |
| <a name="input_type"></a> [type](#input\_type) | worker or controlplane | `string` | n/a | yes |
| <a name="input_vm_bridge"></a> [vm\_bridge](#input\_vm\_bridge) | Proxmox Network Bridge | `string` | `"vmbr0"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_controlplane_config_patches"></a> [controlplane\_config\_patches](#output\_controlplane\_config\_patches) | Controlplane config patches |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig. Output only on type controlplane |
| <a name="output_name"></a> [name](#output\_name) | Cluster Name |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | List of all nodes |
| <a name="output_nodes_ip"></a> [nodes\_ip](#output\_nodes\_ip) | List of IPv6 address to all nodes |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talosctl config. Output only on type controlplane |
| <a name="output_worker_config_patches"></a> [worker\_config\_patches](#output\_worker\_config\_patches) | Worker config patches |
<!-- END_TF_DOCS -->
