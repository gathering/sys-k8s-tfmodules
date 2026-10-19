# DNS Records

Forward DNS records in one existing [Poweradmin](https://www.poweradmin.org) zone: the API name of a cluster, its nodes, the gateway of its VLAN, and any other record. Call the module once per zone.

Each key of `records_by_key` is one record set: a name, a type (`AAAA` by default) and every value of that name and type. Names are fully qualified, such as `api.k8s.gathering.systems`. The module writes them relative to the zone, as Poweradmin expects, and refuses a name outside the zone.

## Forward records only

The module creates no reverse (PTR) records. At The Gathering they come from automation in Netbox, from the DNS names that `talos` (`<node_prefix><key>.<domain_name>`) and `fg-vlan` (`gw.<name>.<domain_name>`) set on the addresses. Give the forward records the same names, so that the forward and reverse records agree.

## Ownership of the record sets

Poweradmin replaces a whole record set on every write. The module therefore owns every record set it has a key for:

- A record set that already exists in Poweradmin, created by hand for example, is taken over on the first apply: its values become the ones given here, without an error or an import.
- A value added in the Poweradmin UI to a record set of the module is removed on the next apply.
- Removing a key deletes its record set, with all its values.

Two keys with the same name and type would overwrite each other, so they are refused at plan time.

## Example

```hcl
provider "poweradmin" {
  api_url = "https://dns.example.org"
  api_key = var.poweradmin_api_key
}

module "dns" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//dns-records?ref=v0.7.0"

  zone_name = "gathering.systems"

  records_by_key = merge(
    {
      api     = { name = "api.my-cluster.gathering.systems", values = [local.cluster_ip] }
      gateway = { name = module.vlan.gateway_dns_name, values = [module.vlan.gateway_ip] }
      grafana = { name = "grafana.gathering.systems", type = "CNAME", values = ["ingress.my-cluster.gathering.systems."] }
    },
    {
      for node in values(module.controlplane.nodes_by_key) :
      node.name => { name = "${node.name}.gathering.systems", values = [node.ip] }
    },
  )
}
```

Keys must be known at plan time: use node names or other names, not addresses.

## Values

- An `AAAA` value must be an IPv6 address without a prefix length. The module writes it in canonical form (`2001:db8::1`, not `2001:DB8:0::1`), so the same address never shows as a change.
- Other values are passed as given. End a host name in a `CNAME` or `NS` value with a dot. Whether Poweradmin quotes `TXT` values itself depends on its `txt_auto_quote` setting.
- Every value has priority 0, so `MX` and `SRV` records with a priority are not supported.

## Prerequisites

- Poweradmin 4.1.0 or later: the provider uses API v2.
- The zone named by `zone_name` must exist.
- An API key of a Poweradmin user that may edit the zone. The provider reads no environment variables: pass `api_url` and `api_key` in the provider block.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_poweradmin"></a> [poweradmin](#requirement\_poweradmin) | ~> 0.6.3 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_poweradmin"></a> [poweradmin](#provider\_poweradmin) | ~> 0.6.3 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [poweradmin_rrset.this](https://registry.terraform.io/providers/poweradmin/poweradmin/latest/docs/resources/rrset) | resource |
| [poweradmin_zone.this](https://registry.terraform.io/providers/poweradmin/poweradmin/latest/docs/data-sources/zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_records_by_key"></a> [records\_by\_key](#input\_records\_by\_key) | Records as a map from a caller-chosen key to a record set:<br/>- `name`: fully qualified name inside `zone_name`, such as `api.k8s.gathering.systems`. A trailing dot is allowed. `zone_name` itself is the zone apex<br/>- `type`: record type, `AAAA` by default<br/>- `ttl`: TTL in seconds, `ttl` by default<br/>- `values`: the contents of the record set, at least one. An `AAAA` value must be an IPv6 address without a prefix length<br/><br/>One key is one record set: give each name and type one key only. | <pre>map(object({<br/>    name   = string<br/>    type   = optional(string, "AAAA")<br/>    ttl    = optional(number)<br/>    values = list(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_ttl"></a> [ttl](#input\_ttl) | TTL in seconds of a record that sets none | `number` | `300` | no |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Poweradmin zone the records are created in, such as `gathering.systems`. The zone must exist; the module looks it up by name | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_records_by_key"></a> [records\_by\_key](#output\_records\_by\_key) | Records as a map from key to an object with `name` (fully qualified, lower case, without the trailing dot), `type`, `ttl` and `values`. AAAA values are in canonical form |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Poweradmin ID of the zone |
<!-- END_TF_DOCS -->
