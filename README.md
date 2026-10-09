# sys-k8s-tfmodules

OpenTofu modules used to deploy and manage Talos Kubernetes clusters at [The Gathering](https://gathering.org).

The modules cover the full infrastructure stack: VM provisioning on Proxmox, IP/VLAN allocation in Netbox, and network configuration on FortiGate — all IPv6-only.

## Modules

| Module | Description |
|---|---|
| [talos](./talos/) | Provisions Talos Kubernetes nodes on Proxmox, registers them in Netbox, and applies machine configuration |
| [fg-k8slb](./fg-k8slb/) | FortiGate IPv6 load balancer VIPs and firewall policy for Kubernetes and Talos APIs |
| [fg-bgp-neighbors](./fg-bgp-neighbors/) | FortiGate IPv6 BGP neighbors and prefix lists for a Kubernetes cluster |
| [fg-policy](./fg-policy/) | Generic FortiGate IPv6 firewall policy with optional NAT64 support |
| [fg-vlan](./fg-vlan/) | Provisions a VLAN end-to-end: allocates VLAN ID and IPv6 prefix in Netbox and creates the interface and address object on FortiGate |

## How the modules fit together

```
fg-vlan  --prefix, prefix_id, vlan_vid-->  talos (controlplane)  --nodes_by_key-->  fg-k8slb.realservers_by_key
                                           talos (worker pools)
                                           talos.nodes_by_key ({name, ip})  -->  fg-bgp-neighbors.neighbors_by_key
fg-vlan  --interface_name, firewall_address_name-->  fg-k8slb / fg-policy interfaces and addresses
fg-k8slb  --calls-->  fg-policy (its API policy)
```

This wiring is inferred from the variable and output shapes, not copied from a live root module. [`examples/full-cluster`](./examples/full-cluster) is a complete root module that validates in CI. A sketch with most inputs left out:

```hcl
resource "talos_machine_secrets" "this" {}

locals {
  controlplanes = { a = 1, b = 2, c = 3 } # node key => realserver id on the load balancer
}

module "vlan" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-vlan?ref=v0.2.0"
  name   = "my-cluster"
  # ...
}

module "controlplane" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//talos?ref=v0.2.0"

  cluster_name               = "my-cluster"
  node_prefix                = "my-cluster-cp-"
  type                       = "controlplane"
  node_keys                  = keys(local.controlplanes)
  cluster_ip                 = local.cluster_ip # same address as fg-k8slb extip
  talos_machine_secrets      = talos_machine_secrets.this.machine_secrets
  talos_client_configuration = talos_machine_secrets.this.client_configuration
  netbox_node_prefix         = module.vlan.prefix
  netbox_node_prefix_id      = module.vlan.prefix_id
  node_vlan_vid              = module.vlan.vlan_vid
  # ...
}

module "workers" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//talos?ref=v0.2.0"

  node_prefix = "my-cluster-w-"
  type        = "worker"
  node_keys   = ["a", "b"]
  # same cluster, secrets and network inputs as the control plane
}

module "k8s_lb" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-k8slb?ref=v0.2.0"

  cluster_name = "my-cluster"
  extip        = local.cluster_ip
  dstintf      = [module.vlan.interface_name]
  realservers_by_key = {
    for key, id in local.controlplanes : key => { id = id, ip = module.controlplane.nodes_by_key[key].ip }
  }
  # ...
}

module "bgp_neighbors" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-bgp-neighbors?ref=v0.2.0"

  cluster_name = "my-cluster"
  neighbors_by_key = {
    for node in concat(values(module.controlplane.nodes_by_key), values(module.workers.nodes_by_key)) : node.name => node
  }
  # ...
}
```

### Stable keys

Node addresses do not exist before the first apply, so nothing can be tracked by them: OpenTofu needs the keys of a `for_each` while planning. The keys therefore come from the caller. Node names are built from them and are known while planning too, which is why `fg-bgp-neighbors` can be keyed by node name. `talos` takes `node_keys`, names each node `<node_prefix><key>` and returns `nodes_by_key`; `fg-bgp-neighbors` takes `neighbors_by_key` and `fg-k8slb` takes `realservers_by_key` with an explicit realserver id per node. Any node can then be removed, and only that node's VM, Netbox records, BGP neighbor and realserver go.

## Conventions

- Every module has `main.tf`, `variables.tf`, `versions.tf` and, when it has outputs, `outputs.tf`. `talos` splits its resources into one file per provider (`netbox.tf`, `proxmox.tf`, `talos.tf`).
- A module's resource of a type is named `this`, also when it has one instance per node.
- Every variable has a type and a description. Validations only reject values that could never have applied, or that are known to break a cluster (empty `pod_subnets`, `service_subnets`, `prefixes`).
- `cluster_name` is the cluster, in every module that needs it. `name` is the name of the one thing a module creates (the VLAN in `fg-vlan`, the policy in `fg-policy`).
- Inputs that are lists on the FortiGate are lists here and keep the FortiGate name: `srcintf`, `dstintf`, `srcaddr6`, `dstaddr6`, in both `fg-policy` and `fg-k8slb`.
- Inputs that refer to something in Netbox start with `netbox_`, and their suffix says what to pass:
  - `netbox_<object>_id`: the numeric Netbox ID, used as is. This is the form for objects that can be created in the same configuration, where a lookup could not be planned (`netbox_node_prefix_id`), and for objects the caller already has by ID (`netbox_site_id`, `netbox_role_id`).
  - `netbox_<object>_name`: the name of an object that exists before the plan; the module looks it up (`netbox_cluster_name`, `netbox_device_role_name`, `netbox_vlan_group_name`).
  - a prefix in CIDR notation has neither suffix (`netbox_node_prefix`, `netbox_base_prefix`).
  - An ID in an output is a Netbox ID only when the name says so (`prefix_id`). The VLAN ID on the wire is `vlan_vid`, as in `node_vlan_vid`.
- An input that tracks things by a caller-chosen key ends in `_by_key`, and so does the matching output (`nodes_by_key`, `neighbors_by_key`, `realservers_by_key`).
- Everything is IPv6. Node addresses in outputs carry no prefix length.
- Modules do not commit a lock file; the consuming root module does.
- Site-specific values are variables whose defaults are the values used at The Gathering.
- A module that calls another module of this repository uses a relative source (`../fg-policy`). OpenTofu fetches the whole repository for a `git::...//<module>?ref=` source, so the path resolves there as well, at the same ref.
- Tests live in `<module>/tests` and run with `tofu test` against mocked providers. `examples/` uses relative module sources so that CI validates it against the modules of the same commit.
- Run `pre-commit run --all-files` before pushing. It runs the same checks as CI: `tofu fmt`, `tofu validate`, `tofu test`, `tflint` and the terraform-docs check.

## Versioning

Releases are git tags (`vMAJOR.MINOR.PATCH`) and are listed in [CHANGELOG.md](./CHANGELOG.md). Always pin the module source with `?ref=<tag>`; `main` can change at any time.

- Each changelog entry says whether a plan is expected to show changes for unchanged inputs, and which. Anything else in the plan is a bug: stop and report it.
- `v0.1.0` is the first release. There is no upgrade path to it from `main` before it: clusters are redeployed, see [UPGRADING.md](./UPGRADING.md).
- A later release that requires editing module calls, or that moves or replaces resources, says so in its changelog entry and gets a section in UPGRADING.md.
- The minimum OpenTofu version is 1.8, which has no way to deprecate a variable. A renamed or removed input is therefore an error until the module call is edited, not a warning.
- Run a plan against real infrastructure before moving a cluster to a new tag. The modules cannot be planned in CI.

## Prerequisites

| Tool | Purpose |
|---|---|
| [OpenTofu](https://opentofu.org) | Infrastructure provisioning |
| [terraform-docs](https://terraform-docs.io) | Documentation generation |
| Proxmox VE | Hypervisor for Kubernetes VMs |
| Netbox | IPAM and DCIM for IP/VLAN allocation |
| FortiGate | Firewall, BGP, and load balancing |

## Providers

| Provider | Source |
|---|---|
| FortiOS | `fortinetdev/fortios` |
| Netbox | `e-breuninger/netbox` |
| Proxmox | `bpg/proxmox` |
| Talos | `siderolabs/talos` |

## Updating documentation

Module READMEs are generated with [terraform-docs](https://terraform-docs.io). After changing variables or outputs in a module, regenerate its README:

```sh
terraform-docs markdown table --output-file README.md --output-mode inject <module-dir>
```

To regenerate all modules at once:

```sh
for dir in talos fg-k8slb fg-vlan fg-bgp-neighbors fg-policy; do
  terraform-docs markdown table --output-file README.md --output-mode inject "$dir"
done
```
