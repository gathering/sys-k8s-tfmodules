# FortiGate BGP Neighbors

Configures IPv6 BGP neighbors on a FortiGate for a Kubernetes cluster. Creates one BGP neighbor per node with IPv6 soft-reconfiguration and graceful restart enabled, plus inbound and outbound IPv6 prefix lists.

The outbound prefix list denies all prefixes (uses default route). The inbound prefix list permits the prefixes provided via `prefixes`.

## Usage

```hcl
module "bgp_neighbors" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-bgp-neighbors"

  cluster_name = "my-cluster"
  neighbors = [
    { name = "cp-1", ip = "2001:db8::a" },
    { name = "cp-2", ip = "2001:db8::b" },
    { name = "cp-3", ip = "2001:db8::c" },
  ]
  prefixes = [
    { prefix = "2001:db8:1::/48", ge = 64 },
  ]
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
| [fortios_router_prefixlist6.in](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/router_prefixlist6) | resource |
| [fortios_router_prefixlist6.out](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/router_prefixlist6) | resource |
| [fortios_routerbgp_neighbor.this](https://registry.terraform.io/providers/fortinetdev/fortios/latest/docs/resources/routerbgp_neighbor) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster Name | `string` | n/a | yes |
| <a name="input_neighbors"></a> [neighbors](#input\_neighbors) | List of nodes | <pre>list(object({<br/>    name = string<br/>    ip   = string<br/>  }))</pre> | n/a | yes |
| <a name="input_prefixes"></a> [prefixes](#input\_prefixes) | Allowed prefixes | <pre>list(object({<br/>    prefix = string<br/>    ge     = number<br/>  }))</pre> | `[]` | no |
| <a name="input_remote_as"></a> [remote\_as](#input\_remote\_as) | Remote AS Number | `number` | `64513` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
