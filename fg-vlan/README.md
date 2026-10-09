# FortiGate VLANs

Provisions a VLAN end-to-end: allocates the next available VLAN ID from a Netbox VLAN group, allocates an IPv6 prefix from a base prefix, reserves the gateway IP (host 1 of the prefix, e.g. `2001:db8:0:1::1`) in Netbox with the DNS name `gw.<name>.<domain_name>` (set `domain_name = null` for none, which a `name` with spaces or other characters not allowed in a DNS name needs), creates a VLAN sub-interface on FortiGate, and registers a firewall address object for the prefix.

## Usage

```hcl
module "vlan_servers" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-vlan?ref=v0.2.0"

  name                   = "servers"
  netbox_vlan_group_name = "prod-vlans"
  netbox_role_id         = 5
  netbox_base_prefix     = "2001:db8::/32"
}
```

## Outputs and what they name

| Output | Is | Feeds |
|---|---|---|
| `interface_name` | The FortiGate interface, `vlan<VLAN ID>` | `srcintf` / `dstintf` of `fg-policy` and `fg-k8slb` |
| `firewall_address_name` | The FortiGate address object of the prefix | `srcaddr6` / `dstaddr6` |
| `vlan_vid` | The VLAN ID on the wire | `node_vlan_vid` of `talos` |
| `prefix`, `prefix_id` | The prefix in CIDR notation and its Netbox ID | `netbox_node_prefix`, `netbox_node_prefix_id` of `talos` |
| `netbox_vlan_name` | The VLAN name in Netbox, which is the `name` input | |

## Tests

`tofu test` in this directory runs the tests in [`tests`](./tests) with both providers mocked, so no credentials are needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_fortios"></a> [fortios](#requirement\_fortios) | ~> 1.26 |
| <a name="requirement_netbox"></a> [netbox](#requirement\_netbox) | ~> 5.8 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_fortios"></a> [fortios](#provider\_fortios) | ~> 1.26 |
| <a name="provider_netbox"></a> [netbox](#provider\_netbox) | ~> 5.8 |

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
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | DNS domain. The gateway address is named `gw.<name>.<domain_name>` in Netbox, so `name` must then be usable in a DNS name. Null leaves the gateway address without a DNS name | `string` | `"gathering.systems"` | no |
| <a name="input_interface"></a> [interface](#input\_interface) | Interface on fortigate to add vlan to | `string` | `"fg-bond"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of new vlan. Also used as the FortiGate interface alias, which is limited to 25 characters | `string` | n/a | yes |
| <a name="input_netbox_base_prefix"></a> [netbox\_base\_prefix](#input\_netbox\_base\_prefix) | Netbox prefix, in CIDR notation, the VLAN prefix is allocated from | `string` | n/a | yes |
| <a name="input_netbox_role_id"></a> [netbox\_role\_id](#input\_netbox\_role\_id) | Netbox ID of the role set on the VLAN and the prefix | `number` | n/a | yes |
| <a name="input_netbox_vlan_group_name"></a> [netbox\_vlan\_group\_name](#input\_netbox\_vlan\_group\_name) | Name of the Netbox VLAN group the VLAN ID is allocated from | `string` | n/a | yes |
| <a name="input_prefix_length"></a> [prefix\_length](#input\_prefix\_length) | Prefix Length | `number` | `64` | no |
| <a name="input_vdom"></a> [vdom](#input\_vdom) | Fortigate VDOM | `string` | `"root"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_firewall_address_name"></a> [firewall\_address\_name](#output\_firewall\_address\_name) | Name of the FortiGate IPv6 address object for the prefix |
| <a name="output_interface_name"></a> [interface\_name](#output\_interface\_name) | FortiGate interface name of the VLAN (`vlan<VLAN ID>`) |
| <a name="output_netbox_vlan_name"></a> [netbox\_vlan\_name](#output\_netbox\_vlan\_name) | Name of the VLAN in Netbox, as given in `name`. Also the alias of the FortiGate interface |
| <a name="output_prefix"></a> [prefix](#output\_prefix) | Prefix of the VLAN in CIDR notation |
| <a name="output_prefix_id"></a> [prefix\_id](#output\_prefix\_id) | Netbox ID of the prefix |
| <a name="output_vlan_vid"></a> [vlan\_vid](#output\_vlan\_vid) | VLAN ID (802.1Q tag), not the Netbox ID of the VLAN |
<!-- END_TF_DOCS -->
