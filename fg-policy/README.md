# FortiGate Policy

Generic FortiGate IPv6 firewall policy with optional NAT64 support. Creates an accept policy with flow inspection and full traffic logging.

When `nat64 = true`, NAT64 is enabled using the IP pool named by `nat64_pool` and `srcaddr`/`dstaddr` are set to `all`.

`fg-k8slb` creates its policy with this module.

## Prerequisites

The following objects must already exist on the FortiGate:
- SSL inspection profile named by `ssl_ssh_profile` (default `SSL-Monitor`)
- IP pool named by `nat64_pool` (default `NAT64-POOL`, only required when `nat64 = true`)

## Usage

```hcl
module "policy" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-policy?ref=v0.1.0"

  name     = "k8s-egress"
  srcintf  = ["vlan100"]
  srcaddr6 = ["k8s-nodes"]
  dstintf  = ["wan1"]
  dstaddr6 = ["all"]
  services = ["ALL"]
}
```

## Source NAT

The FortiGate provider treats an argument that is not set differently from one set to `disable`: it leaves the value on the device alone. `nat = null`, the default, does not set `nat`. `false` sets it to `disable`, `true` to `enable`.

## Tests

`tofu test` in this directory runs the tests in [`tests`](./tests) with the provider mocked, so no credentials are needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_fortios"></a> [fortios](#requirement\_fortios) | ~> 1.26 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_fortios"></a> [fortios](#provider\_fortios) | ~> 1.26 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [fortios_firewall_policy.this](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/firewall_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_comments"></a> [comments](#input\_comments) | Policy comment. Defaults to `<name> - Created by Terraform Provider for FortiOS` | `string` | `null` | no |
| <a name="input_dstaddr6"></a> [dstaddr6](#input\_dstaddr6) | Destination IPv6 addresses | `list(string)` | n/a | yes |
| <a name="input_dstintf"></a> [dstintf](#input\_dstintf) | Destination interfaces | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of policy | `string` | n/a | yes |
| <a name="input_nat"></a> [nat](#input\_nat) | Source NAT (`nat`) on the policy. Null leaves it unset | `bool` | `null` | no |
| <a name="input_nat64"></a> [nat64](#input\_nat64) | Enable NAT64 | `bool` | `false` | no |
| <a name="input_nat64_pool"></a> [nat64\_pool](#input\_nat64\_pool) | IP pool used when `nat64` is true | `string` | `"NAT64-POOL"` | no |
| <a name="input_services"></a> [services](#input\_services) | Services | `list(string)` | n/a | yes |
| <a name="input_srcaddr6"></a> [srcaddr6](#input\_srcaddr6) | Source IPv6 addresses | `list(string)` | n/a | yes |
| <a name="input_srcintf"></a> [srcintf](#input\_srcintf) | Source interfaces | `list(string)` | n/a | yes |
| <a name="input_ssl_ssh_profile"></a> [ssl\_ssh\_profile](#input\_ssl\_ssh\_profile) | SSL/SSH inspection profile | `string` | `"SSL-Monitor"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_policy_id"></a> [policy\_id](#output\_policy\_id) | ID of the firewall policy |
<!-- END_TF_DOCS -->
