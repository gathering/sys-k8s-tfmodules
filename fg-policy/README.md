# FortiGate Policy

Generic FortiGate IPv6 firewall policy with optional NAT64 support. Creates an accept policy with flow inspection and full traffic logging.

When `nat64 = true`, NAT64 is enabled using the `NAT64-POOL` IP pool and `srcaddr`/`dstaddr` are set to `all`.

## Prerequisites

The following objects must already exist on the FortiGate:
- SSL inspection profile: `SSL-Monitor`
- IP pool: `NAT64-POOL` (only required when `nat64 = true`)

## Usage

```hcl
module "policy" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-policy"

  name     = "k8s-egress"
  srcintf  = "vlan100"
  srcaddr6 = ["k8s-nodes"]
  dstintf  = "wan1"
  dstaddr6 = ["all"]
  services = ["ALL"]
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

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_dstaddr6"></a> [dstaddr6](#input\_dstaddr6) | Destination IPv6 addresses | `list(string)` | n/a | yes |
| <a name="input_dstintf"></a> [dstintf](#input\_dstintf) | Destination interface | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of policy | `string` | n/a | yes |
| <a name="input_nat64"></a> [nat64](#input\_nat64) | Enable NAT64 | `bool` | `false` | no |
| <a name="input_services"></a> [services](#input\_services) | Services | `list(string)` | n/a | yes |
| <a name="input_srcaddr6"></a> [srcaddr6](#input\_srcaddr6) | Source IPv6 addresses | `list(string)` | n/a | yes |
| <a name="input_srcintf"></a> [srcintf](#input\_srcintf) | Source interface | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
