# FortiGate VLANs

Provisions a VLAN end-to-end: allocates the next available VLAN ID from a Netbox VLAN group, allocates an IPv6 prefix from a base prefix, reserves the gateway IP (`.1`) in Netbox, creates a VLAN sub-interface on FortiGate, and registers a firewall address object for the prefix.

## Usage

```hcl
module "vlan_servers" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-vlan"

  name           = "servers"
  vlan_group     = "prod-vlans"
  netbox_role_id = 5
  base_prefix    = "2001:db8::/32"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_fortios"></a> [fortios](#provider\_fortios) | n/a |
| <a name="provider_netbox"></a> [netbox](#provider\_netbox) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [fortios_firewall_address6.this](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/firewall_address6) | resource |
| [fortios_system_interface.this](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/system_interface) | resource |
| [netbox_available_prefix.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/available_prefix) | resource |
| [netbox_available_vlan.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/available_vlan) | resource |
| [netbox_ip_address.gw](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/ip_address) | resource |
| [netbox_prefix.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/data-sources/prefix) | data source |
| [netbox_vlan_group.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/data-sources/vlan_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_base_prefix"></a> [base\_prefix](#input\_base\_prefix) | Base Prefix used to get new vlan prefix | `string` | n/a | yes |
| <a name="input_bastion_address_group"></a> [bastion\_address\_group](#input\_bastion\_address\_group) | IP to bastion hosts to access this vlan | `string` | `"bastions-v6"` | no |
| <a name="input_infra_zone"></a> [infra\_zone](#input\_infra\_zone) | Fortigate zone where bastions are located | `string` | `"Infra"` | no |
| <a name="input_interface"></a> [interface](#input\_interface) | Inteface on fortigate to add vlan to | `string` | `"fg-bond"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of new vlan | `string` | n/a | yes |
| <a name="input_netbox_role_id"></a> [netbox\_role\_id](#input\_netbox\_role\_id) | Netbox Role ID | `number` | n/a | yes |
| <a name="input_prefix_length"></a> [prefix\_length](#input\_prefix\_length) | Prefix Length | `number` | `64` | no |
| <a name="input_vdom"></a> [vdom](#input\_vdom) | Fortigate VDOM | `string` | `"root"` | no |
| <a name="input_vlan_group"></a> [vlan\_group](#input\_vlan\_group) | VLAN group name | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_firewall_address_name"></a> [firewall\_address\_name](#output\_firewall\_address\_name) | firewall\_address\_name |
| <a name="output_name"></a> [name](#output\_name) | Interface Name |
| <a name="output_prefix"></a> [prefix](#output\_prefix) | Prefix |
| <a name="output_prefix_id"></a> [prefix\_id](#output\_prefix\_id) | Prefix ID |
| <a name="output_vlan_id"></a> [vlan\_id](#output\_vlan\_id) | VLAN ID |
| <a name="output_vlan_name"></a> [vlan\_name](#output\_vlan\_name) | VLAN Name |
<!-- END_TF_DOCS -->
