# FortiGate LB for k8s and Talos controlplane

Creates three FortiGate IPv6 VIPs (server-load-balance) for the Kubernetes API (6443), Talos control API (50001), and talosctl API (50000), plus a single firewall policy accepting traffic to all three.

The policy is created by the [`fg-policy`](../fg-policy) module, called with a relative source. That resolves when this module is used from a git source too, because OpenTofu fetches the whole repository and then enters the `fg-k8slb` directory. The policy allows service `ALL`: the VIPs only listen on their own port. Source NAT is off.

## Prerequisites

The following objects must already exist on the FortiGate:
- Health monitor named by `monitor` (default `tcp-check`)
- SSL inspection profile named by `ssl_ssh_profile` (default `SSL-Monitor`)
- Source address objects/groups passed via `srcaddr6`

## Usage

```hcl
module "k8s_lb" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-k8slb?ref=v0.1.0"

  cluster_name = "my-cluster"
  extip        = "2001:db8::1"
  dstintf      = ["vlan100"]
  srcintf      = ["wan1"]
  srcaddr6     = ["all"]

  realservers_by_key = {
    a = { id = 1, ip = "2001:db8::a" }
    b = { id = 2, ip = "2001:db8::b" }
    c = { id = 3, ip = "2001:db8::c" }
  }
}
```

## Realservers

`realservers_by_key` is a map of nodes with an explicit realserver `id` each. Removing or adding a node leaves id and address of the others as they are. Never give the id of a node to another one while the first still exists. With a `talos` pool:

```hcl
locals {
  controlplanes = { a = 1, b = 2, c = 3 } # node key => realserver id
}

realservers_by_key = {
  for key, id in local.controlplanes : key => { id = id, ip = module.controlplane.nodes_by_key[key].ip }
}
```

A membership change is an in-place update of the three VIPs. The realservers are a list inside the VIP, so the plan shows the change by position: after removing the realserver with id 2 of three it reads `id = 2 -> 3` on the second entry and removes the third. The entries left are the same ids with the same addresses.

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

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_policy"></a> [policy](#module\_policy) | ../fg-policy | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [fortios_firewall_vip6.this](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/firewall_vip6) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster name. Prefix of the VIP and policy names | `string` | n/a | yes |
| <a name="input_dstintf"></a> [dstintf](#input\_dstintf) | Dst interfaces for policy | `list(string)` | n/a | yes |
| <a name="input_extip"></a> [extip](#input\_extip) | External IPv6 address | `string` | n/a | yes |
| <a name="input_monitor"></a> [monitor](#input\_monitor) | Health monitor name for VIP realservers | `string` | `"tcp-check"` | no |
| <a name="input_realservers_by_key"></a> [realservers\_by\_key](#input\_realservers\_by\_key) | Control-plane nodes by a key known at plan time, each with an explicit realserver `id` and its address (IPv6). At least one. Adding or removing a node leaves the others untouched | <pre>map(object({<br/>    id = number<br/>    ip = string<br/>  }))</pre> | n/a | yes |
| <a name="input_srcaddr6"></a> [srcaddr6](#input\_srcaddr6) | Src addresses for policy. Must exist as a address or group | `list(string)` | n/a | yes |
| <a name="input_srcintf"></a> [srcintf](#input\_srcintf) | Src interfaces for policy | `list(string)` | n/a | yes |
| <a name="input_ssl_ssh_profile"></a> [ssl\_ssh\_profile](#input\_ssl\_ssh\_profile) | SSL/SSH inspection profile for the policy | `string` | `"SSL-Monitor"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_policy_id"></a> [policy\_id](#output\_policy\_id) | ID of the firewall policy |
| <a name="output_vip_names"></a> [vip\_names](#output\_vip\_names) | Names of the VIPs, keyed by `k8s-api`, `talos-control-api` and `talosctl-api` |
<!-- END_TF_DOCS -->
