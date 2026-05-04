# FortiGate LB for k8s and Talos controlplane

Creates three FortiGate IPv6 VIPs (server-load-balance) for the Kubernetes API (6443), Talos control API (50001), and talosctl API (50000), plus a single firewall policy accepting traffic to all three.

## Prerequisites

The following objects must already exist on the FortiGate:
- Health monitor: `tcp-check`
- SSL inspection profile: `SSL-Monitor`
- Source address objects/groups passed via `srcaddr6`

## Usage

```hcl
module "k8s_lb" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-k8slb"

  name        = "my-cluster"
  extip       = "2001:db8::1"
  realservers = ["2001:db8::a", "2001:db8::b", "2001:db8::c"]
  dstintf     = "vlan100"
  srcintf     = ["wan1"]
  srcaddr6    = ["all"]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_fortios"></a> [fortios](#provider\_fortios) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [fortios_firewall_policy.this](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/firewall_policy) | resource |
| [fortios_firewall_vip6.k8s_api](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/firewall_vip6) | resource |
| [fortios_firewall_vip6.talos_control_api](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/firewall_vip6) | resource |
| [fortios_firewall_vip6.talosctl_api](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/firewall_vip6) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dstintf"></a> [dstintf](#input\_dstintf) | Dst interface for policy | `string` | n/a | yes |
| <a name="input_extip"></a> [extip](#input\_extip) | External IPv6 address | `string` | n/a | yes |
| <a name="input_monitor"></a> [monitor](#input\_monitor) | Health monitor name for VIP realservers | `string` | `"tcp-check"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of LoadBalancer | `string` | n/a | yes |
| <a name="input_realservers"></a> [realservers](#input\_realservers) | List of controlplane nodes (IPv6) | `list(string)` | n/a | yes |
| <a name="input_srcaddr6"></a> [srcaddr6](#input\_srcaddr6) | Src addresses for policy. Must exist as a address or group | `list(string)` | n/a | yes |
| <a name="input_srcintf"></a> [srcintf](#input\_srcintf) | Src interfaces for policy | `list(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
