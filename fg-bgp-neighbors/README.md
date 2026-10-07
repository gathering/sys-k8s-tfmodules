# FortiGate BGP Neighbors

Configures IPv6 BGP neighbors on a FortiGate for a Kubernetes cluster. Creates one BGP neighbor per node with IPv6 soft-reconfiguration and graceful restart enabled, plus inbound and outbound IPv6 prefix lists.

The outbound prefix list denies everything on purpose: nothing is advertised to the cluster, the nodes use their default route. The inbound prefix list permits the prefixes provided via `prefixes`, which must not be empty. Each entry may set `ge` and `le` to accept more specific routes inside the prefix; with neither, only the exact prefix matches.

## Usage

```hcl
module "bgp_neighbors" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-bgp-neighbors?ref=v0.1.0"

  cluster_name = "my-cluster"
  neighbors_by_key = {
    my-cluster-cp-a = { name = "my-cluster-cp-a", ip = "2001:db8::a" }
    my-cluster-cp-b = { name = "my-cluster-cp-b", ip = "2001:db8::b" }
    my-cluster-cp-c = { name = "my-cluster-cp-c", ip = "2001:db8::c" }
  }
  prefixes = [
    { id = 1, prefix = "2001:db8:1::/48", ge = 64 },
    { id = 2, prefix = "2001:db8:2::/64", ge = 128, le = 128 },
  ]
}
```

## Neighbors by key or by position

- `neighbors_by_key` is a map. Each neighbor is tracked by its key, so adding or removing a node leaves the other neighbors alone. The keys must be known at plan time. Names from `talos` pools with `node_keys` are; random node names and addresses are not, since they do not exist before the first apply. With several pools, key by node name, which is unique in a cluster where the pool keys may not be:

  ```hcl
  neighbors_by_key = {
    for node in concat(values(module.controlplane.nodes_by_key), values(module.workers.nodes_by_key)) : node.name => node
  }
  ```

- `neighbors` is a list. Each neighbor is tracked by its position, so removing or reordering a node makes OpenTofu destroy and create every neighbor after it, which drops their BGP sessions. It is what works for `talos` pools without `node_keys`: `neighbors = module.workers.nodes`.

Both can be set at once, for a cluster that has pools of both kinds. A node must appear in only one of them: two neighbors with the same IP fail on apply. Moving a pool from the list to the map is described in the [`talos` README](../talos/README.md#moving-an-existing-pool-to-node-keys).

## Prefix-list rule ids

Give every `prefixes` entry an `id`. It is the rule id in the FortiGate prefix list, and with explicit ids an entry can be removed or inserted without renumbering the others. Without ids the position in the list is the id. Set `id` on all entries or on none. To add ids to an existing list without a change, number the entries 1, 2, 3, ... in their current order.

## Several instances for one cluster

The prefix lists are named `<cluster_name>-in` and `<cluster_name>-out`. A second instance of the module for the same cluster, for example for a pool with other prefixes, needs `prefix_list_name` to give its lists another name.

Do not set `prefix_list_name` on an existing instance. The plan shows a replacement of both prefix lists and an update of every neighbor, but the old lists are destroyed while the neighbors still reference them. FortiOS is expected to refuse that, so the apply would fail part-way. This is the expected behaviour and was not tested. The input is meant for new, additional instances.

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
| [fortios_router_prefixlist6.in](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/router_prefixlist6) | resource |
| [fortios_router_prefixlist6.out](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/router_prefixlist6) | resource |
| [fortios_routerbgp_neighbor.keyed](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/routerbgp_neighbor) | resource |
| [fortios_routerbgp_neighbor.this](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/routerbgp_neighbor) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster Name | `string` | n/a | yes |
| <a name="input_neighbors"></a> [neighbors](#input\_neighbors) | Nodes as a list. Neighbors are tracked by position, so removing or reordering a node recreates the neighbors after it. Use `neighbors_by_key` where the keys can be known at plan time | <pre>list(object({<br/>    name = string<br/>    ip   = string<br/>  }))</pre> | `[]` | no |
| <a name="input_neighbors_by_key"></a> [neighbors\_by\_key](#input\_neighbors\_by\_key) | Nodes as a map. The keys must be known at plan time, so node names from `random_id` or addresses cannot be keys. Adding or removing a node leaves the other neighbors untouched. Can be combined with `neighbors` | <pre>map(object({<br/>    name = string<br/>    ip   = string<br/>  }))</pre> | `{}` | no |
| <a name="input_prefix_list_name"></a> [prefix\_list\_name](#input\_prefix\_list\_name) | Name prefix of the two prefix lists, `<prefix_list_name>-in` and `-out`. Defaults to `cluster_name`. Set it on a second instance of this module for the same cluster, whose lists would otherwise collide | `string` | `null` | no |
| <a name="input_prefixes"></a> [prefixes](#input\_prefixes) | Allowed prefixes, at least one. `ge` and `le` bound the accepted prefix length; without them only the exact prefix matches. `id` is the rule id in the prefix list: set it on every entry or on none. Without ids the position in the list is used, so removing an entry renumbers the ones after it | <pre>list(object({<br/>    prefix = string<br/>    ge     = optional(number)<br/>    le     = optional(number)<br/>    id     = optional(number)<br/>  }))</pre> | n/a | yes |
| <a name="input_remote_as"></a> [remote\_as](#input\_remote\_as) | Remote AS Number | `string` | `"64513"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_neighbor_ips"></a> [neighbor\_ips](#output\_neighbor\_ips) | Addresses of the BGP neighbors from `neighbors`, in the order of that list |
| <a name="output_neighbor_ips_by_key"></a> [neighbor\_ips\_by\_key](#output\_neighbor\_ips\_by\_key) | Addresses of the BGP neighbors from `neighbors_by_key`, by key |
| <a name="output_prefix_list_in_name"></a> [prefix\_list\_in\_name](#output\_prefix\_list\_in\_name) | Name of the inbound IPv6 prefix list |
| <a name="output_prefix_list_out_name"></a> [prefix\_list\_out\_name](#output\_prefix\_list\_out\_name) | Name of the outbound IPv6 prefix list |
<!-- END_TF_DOCS -->
