# Upgrading

## To v0.1.0, from `main` before it

This is the guide for a deployment whose module sources track `main` as it was before v0.1.0, unpinned. The only earlier tag, `v0.0.1`, is much older than that `main` and has another interface; an upgrade from it is not covered here. v0.1.0 changes the interface of all five modules and the behaviour of `talos`, so the upgrade has two parts:

1. Edit every module call. Until that is done nothing plans: the minimum OpenTofu version is 1.8, which cannot deprecate a variable, so a call that still uses an old name fails with `Unsupported argument` or `Missing required argument`. Nothing is applied half-way.
2. Apply the plan that results. It is not empty: it updates the config apply of every node and replaces machine config snippet files. [Expected plan](#expected-plan) lists exactly what it must contain, and [Rollout](#rollout) how to apply it.

Order of work:

1. Check the [prerequisites](#prerequisites).
2. Start from a plan without changes on the modules you run today.
3. Set `?ref=v0.1.0` on every module source, make the [edits](#edits-to-the-module-calls) and run `tofu init`.
4. Plan and compare with the [expected plan](#expected-plan). Anything else is a bug or a missed edit: do not apply it.
5. Apply as described under [Rollout](#rollout), a test cluster first.
6. Later, and one at a time: the [optional features](#optional-features-after-the-upgrade).

### Prerequisites

- OpenTofu 1.8 or later. Every module sets `required_version = ">= 1.8"`.
- The modules now constrain their providers:

  | Provider | Constraint |
  |---|---|
  | `bpg/proxmox` | `~> 0.116.0` |
  | `e-breuninger/netbox` | `~> 5.8` |
  | `siderolabs/talos` | `~> 0.12.0` |
  | `fortinetdev/fortios` | `~> 1.26` |
  | `hashicorp/random` | `~> 3.9` |

- `tofu init` is needed in any case, because the module sources change and `fg-k8slb` now contains a nested module. If the lock file of the root module holds a provider version older than these constraints, it has to be `tofu init -upgrade`.
- A provider upgrade can show plan changes of its own, which this guide does not cover. If `-upgrade` changed a provider version, the cleanest order is to upgrade the providers first, on the modules you run today, and get a plan without changes before touching the module sources. Which provider versions existing deployments have in their lock file is not known here.
- `fg-bgp-neighbors`, `fg-k8slb` and `fg-policy` no longer require the `netbox` provider, which they never used. A call of one of these modules that passes it explicitly, `providers = { netbox = ... }`, has to drop that entry: with it, `tofu validate` and `tofu plan` fail with `Provider type mismatch`.
- `talos` declares `hashicorp/random`, which it already used. Nothing to do.

### Edits to the module calls

Each table lists what a call or a reference to an output has to change. Inputs and outputs that are not listed keep their name, type and default.

#### `fg-vlan`

| Old | New | Edit |
|---|---|---|
| input `vlan_group` | `netbox_vlan_group_name` | Rename the argument. Same value |
| input `base_prefix` | `netbox_base_prefix` | Rename the argument. Same value |
| input `infra_zone` | removed | Delete the argument if set. It was never used |
| input `bastion_address_group` | removed | Delete the argument if set. It was never used |
| input `name`, any length | at most 25 characters | Nothing for an existing VLAN: the name is the FortiGate interface alias, which has that limit |
| output `vlan_name` | `interface_name` | Replace `module.<vlan>.vlan_name` with `module.<vlan>.interface_name`. Same value, the FortiGate interface name `vlan<VLAN ID>` |
| output `name` | `netbox_vlan_name` | Replace `module.<vlan>.name` with `module.<vlan>.netbox_vlan_name`. Same value, the `name` input |
| output `vlan_id` | `vlan_vid` | Replace `module.<vlan>.vlan_id` with `module.<vlan>.vlan_vid`. Same value, the VLAN ID on the wire |

`netbox_role_id`, `interface`, `prefix_length` and `vdom`, and the outputs `prefix`, `prefix_id` and `firewall_address_name` are unchanged.

```hcl
# before
module "vlan" {
  source         = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-vlan"
  name           = "my-cluster"
  vlan_group     = "prod-vlans"
  netbox_role_id = 5
  base_prefix    = "2001:db8::/48"
}

# after
module "vlan" {
  source                 = "git::https://github.com/gathering/sys-k8s-tfmodules.git//fg-vlan?ref=v0.1.0"
  name                   = "my-cluster"
  netbox_vlan_group_name = "prod-vlans"
  netbox_role_id         = 5
  netbox_base_prefix     = "2001:db8::/48"
}
```

#### `talos`

| Old | New | Edit |
|---|---|---|
| input `pod_subnets`, untyped, default `[]` | `list(string)`, required, non-empty, valid CIDRs | Nothing if it is set to a non-empty list, which every cluster is assumed to do. A call without it must add it with the value the cluster runs with; see below |
| input `service_subnets`, untyped, default `[]` | `list(string)`, required, non-empty, valid CIDRs | The same |
| input `netbox_cluster` | `netbox_cluster_name` | Rename the argument if set. Same value, same default `pve` |
| input `netbox_device_role` | `netbox_device_role_name` | Rename the argument if set. Same value, same default `Server` |
| input `oidc_issuer_url` set, `oidc_client_id` not set | rejected at plan time | Set `oidc_client_id`. kube-apiserver does not start with only one of the two |
| input `oidc_issuer_url = null`, passed explicitly | OIDC is off, as with `""` or with the argument left out | Nothing, if OIDC is meant to be off. Before, this rendered the other `oidc-*` API server arguments with a null issuer; the plan now removes them, see the "OIDC off" row of the expected plan |
| inputs `oidc_issuer_url`, `oidc_client_id`, default `""` | default `null` | Nothing. `null` and `""` both mean unset, for every `oidc_*` input |
| input `talos_machine_secrets`, untyped | typed object, sensitive | Nothing when it is the `machine_secrets` attribute of a `talos_machine_secrets` resource |
| input `talos_client_configuration`, untyped | typed object | Nothing when it is the `client_configuration` attribute of a `talos_machine_secrets` resource |
| input `talos_inline_manifests`, untyped | list of objects with `name` and `contents` | Nothing for entries with exactly those two keys. Any other attribute on an entry, which Talos rejected before, is now dropped |
| input `type`, any string | `controlplane` or `worker` | Nothing. Other values failed before |
| input `nodes`, any number | a whole number, 0 or greater; at least 1 for a control-plane pool | Nothing. Other values failed before |
| input `cluster_name`, any string | not empty | Nothing |
| input `node_prefix`, any string | letters, digits, hyphens and dots, starting with a letter or digit; may be empty | Nothing. Proxmox rejects any other VM name |
| input `netbox_node_prefix_id`, required | optional, default `null`; required unless `netbox_node_prefix_lookup` is true | Nothing. Keep passing it |
| output `name` | `cluster_name` | Replace `module.<pool>.name` with `module.<pool>.cluster_name`. Same value |
| output `controlplane_config_patches`, two elements | one element | Replace `controlplane_config_patches[1]` with `[0]`, which now holds everything |
| output `worker_config_patches` | one element as before, without the control-plane settings | Nothing, unless the caller reads those settings out of it |

New and optional, each with a default that keeps an existing pool as it is: `node_keys`, `apply_mode`, `on_destroy`, `snippet_per_pool`, `snippet_datastore`, `proxmox_nodes`, `proxmox_online_only`, `netbox_node_prefix_lookup`, `gateway`, `template_vm_id`, `template_node_name`, `on_boot`, `agent_enabled`, `tags`, `description`, and the output `nodes_by_key`. "As it is" refers to the resources; the defaults of `apply_mode` and `on_destroy` do show up in the plan, see [Expected plan](#expected-plan). The outputs `nodes`, `nodes_ip`, `kubeconfig` and `talosconfig` are unchanged.

If a pool does not set `pod_subnets` or `service_subnets` today: stop. Its machine config has empty subnet lists, and setting them now changes the config of a running cluster. Find out what the cluster actually uses before choosing a value.

For a `talos_inline_manifests` entry without `name` or `contents`, the `controlplane_config_patches` output shows that key as `null` instead of leaving it out. The rendered machine config is the same.

#### `fg-k8slb`

| Old | New | Edit |
|---|---|---|
| input `name` | `cluster_name` | Rename the argument. Same value. The VIPs and the policy keep their names |
| input `dstintf`, a string | a list of strings, at least one | Put the value in brackets: `dstintf = "vlan100"` becomes `dstintf = ["vlan100"]`, `dstintf = module.vlan.vlan_name` becomes `dstintf = [module.vlan.interface_name]` |
| input `srcintf`, a list of strings | the same, at least one | Nothing |
| input `realservers`, required | optional, exactly one of `realservers` and `realservers_by_key` | Nothing. Keep `realservers` as it is |

`extip`, `srcaddr6` and `monitor` are unchanged. New and optional: inputs `ssl_ssh_profile` (default `SSL-Monitor`, the value that was hardcoded) and `realservers_by_key`; outputs `vip_names` and `policy_id`.

Resource addresses change. `moved` blocks in the module carry the state over, so there is nothing to do in the root module:

| From | To |
|---|---|
| `module.<lb>.fortios_firewall_vip6.k8s_api` | `module.<lb>.fortios_firewall_vip6.this["k8s-api"]` |
| `module.<lb>.fortios_firewall_vip6.talos_control_api` | `module.<lb>.fortios_firewall_vip6.this["talos-control-api"]` |
| `module.<lb>.fortios_firewall_vip6.talosctl_api` | `module.<lb>.fortios_firewall_vip6.this["talosctl-api"]` |
| `module.<lb>.fortios_firewall_policy.this` | `module.<lb>.module.policy.fortios_firewall_policy.this` |

The plan shows `has moved to` for each and no change to the VIPs or the policy. If it shows a VIP or the policy being created or destroyed instead, stop. If it shows the policy being updated, compare the attributes: the module passes the same name, interfaces, addresses, service, profile and `nat = "disable"`, sets no comment and leaves `nat64` and `ippool` unset, as before.

The policy is now created by a call of the `fg-policy` module inside `fg-k8slb`. That nested module needs nothing from the caller. Its source is `../fg-policy`, which resolves inside the repository OpenTofu fetches for `git::...//fg-k8slb?ref=v0.1.0`; `tofu init` lists it as `<lb>.policy`. A `providers` argument on the `fg-k8slb` call applies to it as well.

The `moved` blocks exist for this upgrade. They may be removed in a later release, once consumers have applied v0.1.0; the changelog will say so.

#### `fg-policy`

| Old | New | Edit |
|---|---|---|
| input `srcintf`, a string | a list of strings, at least one | Put the value in brackets: `srcintf = "vlan100"` becomes `srcintf = ["vlan100"]` |
| input `dstintf`, a string | a list of strings, at least one | The same |

`name`, `srcaddr6`, `dstaddr6`, `services` and `nat64` are unchanged. New and optional, with defaults that give the policy as before: `ssl_ssh_profile` (`SSL-Monitor`), `nat64_pool` (`NAT64-POOL`), `comments`, `nat`, and `null` as a value of `nat64`; output `policy_id`.

#### `fg-bgp-neighbors`

| Old | New | Edit |
|---|---|---|
| input `prefixes`, default `[]` | required, at least one entry | Nothing if it is set to a non-empty list. A call without it created an inbound prefix list without rules, which accepts no route, and must now say which prefixes to accept |
| `prefixes` entries: `ge` required | `ge` optional | Nothing |
| `prefixes` entries: an `le` key was dropped (OpenTofu 1.12 warns about it, 1.8 does not) | `le` is applied | Check every entry. If one has an `le` key, the plan sets `le` on that rule of `fortios_router_prefixlist6.in` (shown as `le = 0 -> <value>`), which changes which routes the FortiGate accepts. Remove the key to keep the list as it is, or keep it on purpose |
| input `remote_as`, a number, default `64513` | a string, default `"64513"` | Nothing. A number in the call is converted, `remote_as = 64513` still works. The value on the FortiGate is the same |
| input `neighbors`, required | optional, default `[]` | Nothing |

`cluster_name` is unchanged. New and optional: inputs `neighbors_by_key`, `prefix_list_name`, `id` on `prefixes` entries; outputs `neighbor_ips`, `neighbor_ips_by_key`, `prefix_list_in_name` and `prefix_list_out_name`.

### Expected plan

With the edits above made and nothing new turned on:

| Resource | Expected |
|---|---|
| `talos_machine_configuration_apply.this[*]`, every pool | Update in place: `apply_mode` `auto` -> `staged_if_needing_reboot`, `on_destroy` added |
| The same, on worker pools | Additionally `machine_configuration_input`, `machine_configuration` and `machine_configuration_hash` change: the control-plane settings are removed |
| The same, on control-plane pools with OIDC off | Additionally the same three attributes change: the OIDC `ClusterRoleBinding` manifest is removed |
| The same, on control-plane pools with OIDC on and `oidc_groups_prefix` other than `oidc:`, or one of `oidc_username_claim`, `oidc_username_prefix`, `oidc_groups_claim`, `oidc_groups_prefix` set to `null` or `""` | Additionally the same three attributes change: null arguments are gone, the binding names the group with the prefix |
| `proxmox_virtual_environment_file.this[*]` of every pool whose config changes per the three rows above | Replaced, forced by `source_raw.data`. Same file name |
| `fortios_firewall_vip6.k8s_api`, `.talos_control_api`, `.talosctl_api` in every `fg-k8slb` instance | Moved to `fortios_firewall_vip6.this["k8s-api"]`, `["talos-control-api"]`, `["talosctl-api"]`. No change |
| `fortios_firewall_policy.this` in every `fg-k8slb` instance | Moved to `module.policy.fortios_firewall_policy.this` in that instance. No change |
| `fortios_router_prefixlist6.in`, only where a `prefixes` entry has an `le` key | Update in place: `le = 0 -> <value>` on that rule |
| Everything else, in particular every `netbox_*` resource, `random_id`, `proxmox_virtual_environment_vm`, `talos_machine_bootstrap`, `talos_cluster_kubeconfig`, and every other `fortios_*` resource | No change |

Anything else in the plan is a bug or a missed edit: do not apply it, report it.

Any other control-plane pool with OIDC on, so in particular one with the four inputs at their defaults, renders a byte-identical machine config, also with `talos_inline_manifests` set: its snippet files are untouched and its config applies only show `apply_mode` and `on_destroy`.

"OIDC off" means `oidc_issuer_url` is not set, `""` or `null`.

The only resources the plan adds or destroys are the snippet files it replaces. Nothing is planned on any `netbox_available_vlan`, `netbox_available_prefix`, `netbox_available_ip_address`, `random_id` or `proxmox_virtual_environment_vm`.

The plan also prints one `staged_if_needing_reboot is not supported on Talos 1.14+` warning per node, on this and every later plan, whatever Talos version the nodes run. See [Config apply mode](#config-apply-mode).

### What changes on the nodes

#### Worker machine config

Workers lose the settings Talos reads on control planes only (checked in the Talos v1.11.0 and v1.14.0 source): `cluster.apiServer` (certificate SANs and the OIDC arguments), `cluster.allowSchedulingOnControlPlanes`, `cluster.inlineManifests` (the OIDC binding), `cluster.proxy` and `cluster.network.cni`. CNI `none` and the disabled kube-proxy are still set, through the control planes.

#### Control-plane machine config and the OIDC binding

Talos only creates the objects of an inline manifest when they are missing. It does not update or delete them (checked in the Talos v1.11.0 source). The first two cases below follow from that.

- OIDC off: the control planes lose the inline manifest `oidc-<cluster_name>-cluster-admin`, which was rendered whether OIDC was on or not. The `ClusterRoleBinding` stays in the cluster. It names a group nobody is in while OIDC is off; remove it with `kubectl delete clusterrolebinding oidc-<cluster_name>-cluster-admin`. Where `oidc_issuer_url = null` was passed explicitly, the `oidc-*` API server arguments that were rendered with a null issuer are removed as well.
- OIDC on with `oidc_groups_prefix` other than `oidc:` (including `""` and `null`): the binding named the group `oidc:<cluster_name>-cluster-admin` whatever the prefix, so it never matched. The manifest now names `<oidc_groups_prefix><cluster_name>-cluster-admin`. In an existing cluster the old binding object stays as it is until it is deleted with the command above; Talos then creates the new one, and members of the identity provider group `<cluster_name>-cluster-admin` become cluster admins. Check who is in that group first. New clusters get the working binding from the start.
- OIDC on with a claim or prefix set to `null` or `""`: kube-apiserver gets no argument instead of one rendered from a null value. How Talos passed the null on was not checked against a cluster; expect kube-apiserver to restart on the control planes when this applies.

#### Config apply mode

`apply_mode` is new and defaults to `staged_if_needing_reboot` instead of the provider default `auto`.

- On nodes running Talos before 1.14, a change that needs a reboot is staged and takes effect at the next reboot you do; anything else is applied live.
- On nodes running Talos 1.14 or later, Talos itself does not reboot on a config apply (read in the Talos 1.14 source and release notes, not tested): the config is applied live and whatever needs a reboot takes effect at your next reboot. `apply_mode = "staged"` should not be needed to avoid reboots there, although the provider warning suggests it; it applies nothing live.
- The `not supported on Talos 1.14+` warning is keyed on the provider build (0.12.0 bundles the Talos 1.14 machinery), not on the node version, so it is printed whatever the nodes run.
- `apply_mode = "auto"` gives the behaviour before v0.1.0.

#### Node removal

`on_destroy` is new. Its default does not reset, so removing a node works as before: the VM is deleted without telling Talos. The plan still shows `on_destroy` being added to every config apply.

#### Snippet files

The snippet name and the VMs' reference to it do not change in this upgrade: `snippet_per_pool` is off by default. Where the rendered config changes, the files are replaced under the same name: the provider deletes and uploads again. A VM that starts on that host in between fails to start and can be started again afterwards.

Pools that share a snippet name today, that is pools of the same type in one cluster, each replace the same file in this upgrade, because the worker config changes. `-parallelism=1` keeps them from racing. Until such pools are moved to `snippet_per_pool` their inputs have to stay identical, as before.

### Rollout

1. Upgrade a test cluster first, then production, in a maintenance window.
2. Check that every node of every pool is up and answers on tcp/50000 from the machine running OpenTofu. The apply itself, not only the plan, contacts all of them, including control planes whose config is unchanged: the provider sends the config again on any update of a config apply and retries for up to the 10-minute timeout (read in the provider source, not tested). One node being down fails the apply.
3. Plan and compare with the [expected plan](#expected-plan). During the plan the provider does a dry run against every node whose config changes, to learn whether the change needs a reboot. Read the warnings: `Reboot prevented - using staged mode` means the config of that node will be staged; `Cannot check reboot requirement` means the node could not be reached and gets `auto`, which on a node running Talos before 1.14 may reboot it if the change needs it. Fix the access and plan again instead of applying that.
4. Apply the control-plane module first and one resource at a time: `tofu apply -parallelism=1 -target=module.<controlplane>`. Check the cluster (`talosctl health`, `kubectl get nodes`), then apply the rest, also with `-parallelism=1`. The `fg-k8slb` moves and the worker changes show up in this second, untargeted apply, which is expected.
5. If a config was staged, or on Talos 1.14 and later if part of a change needs a reboot, activate it by rebooting that node: `talosctl -n <node> reboot`. One node at a time, control planes first, waiting for etcd and the node to be healthy in between. None of the config changes in this upgrade is expected to need a reboot; confirm that in the test cluster.
6. Do the manual steps that apply from [Control-plane machine config and the OIDC binding](#control-plane-machine-config-and-the-oidc-binding).
7. Plan again. It must show no changes.

### Optional features after the upgrade

None of these is needed for the upgrade. Turn them on later, one at a time; each has its own expected plan.

- **Per-pool snippet names** (`talos` `snippet_per_pool`). Set it on new pools. Do not just turn it on for an existing pool: the old file is deleted, existing VMs still point at it in their Proxmox config and then fail their next start (stop and start, host reboot, HA recovery). The procedure, with a `qm set` per VM, is in the [`talos` README, "Snippet name"](./talos/README.md#snippet-name). Turning it on plans a replacement of the pool's snippet files (forced by `source_raw.file_name`) and nothing else.
- **Reset on destroy** (`talos` `on_destroy = { reset = true }`). A removed node is reset first, so a removed control plane leaves etcd. The provider reads the setting from state, so it has to be applied before the scale-down it should affect. A node that is down then blocks its destroy for the 10-minute timeout, the reset does not delete the Kubernetes `Node` object, and before destroying a whole cluster the reset has to be turned off again and applied. See the [`talos` README, "Removing nodes"](./talos/README.md#removing-nodes).
- **Pinned or online-only placement** (`talos` `proxmox_nodes`, `proxmox_online_only`). By default placement is unchanged and still includes offline hosts. Setting `proxmox_nodes` on an existing pool deletes the snippet from hosts left out of the list. See the [`talos` README, "Placement"](./talos/README.md#placement).
- **Prefix lookup** (`talos` `netbox_node_prefix_lookup`). Do not turn it on for an existing pool unless the lookup returns the id that was passed before: a different id replaces the node addresses. See the [`talos` README, "Node prefix and gateway"](./talos/README.md#node-prefix-and-gateway).
- **Stable node keys** (`talos` `node_keys`, `fg-bgp-neighbors` `neighbors_by_key`, `fg-k8slb` `realservers_by_key`). Nodes, BGP neighbors and realservers are tracked by a key the caller chooses instead of by position, so that any node can be removed without touching the others. Use it for every new pool; `examples/full-cluster` does. Moving an existing pool keeps its node names and addresses and is a procedure of its own with `moved` blocks: [`talos` README, "Moving an existing pool to node keys"](./talos/README.md#moving-an-existing-pool-to-node-keys). Expected plan of that procedure: moves without changes, plus the pool's `random_id.this[*]` destroyed, which only removes them from state.
- **Prefix-list rule ids** (`fg-bgp-neighbors` `prefixes[*].id`). Numbering the existing entries 1, 2, 3, ... in their current order plans no change. From then on entries can be removed or inserted without renumbering. See the [`fg-bgp-neighbors` README](./fg-bgp-neighbors/README.md#prefix-list-rule-ids).
- **A second BGP instance for one cluster** (`fg-bgp-neighbors` `prefix_list_name`). Only for a new, additional instance of the module. Do not set it on an existing instance: the plan shows a replacement of both prefix lists and an update of every neighbor, but the old lists are destroyed while the neighbors still reference them. FortiOS is expected to refuse that, so the apply would fail part-way. This is the expected behaviour and was not tested. See the [`fg-bgp-neighbors` README](./fg-bgp-neighbors/README.md#several-instances-for-one-cluster).
- **Unset policy arguments** (`fg-policy` `comments`, `nat`, `nat64 = null`). See the [`fg-policy` README](./fg-policy/README.md#unset-arguments).

### How this was verified

Nothing was run against real Netbox, Proxmox, Talos or FortiGate, and no plan was made against the state of a real deployment. The expected plan has to be confirmed in a test cluster, the effect of `apply_mode` on running nodes in particular.

What was done, with OpenTofu 1.8.11 and 1.12.6 and the real providers (netbox 5.8.0, proxmox 0.116.0, talos 0.12.0, fortios 1.26.1, random 3.9.1):

- The plan behind the table was produced against synthesised state: a root module using all five modules as they were on `main` (three control planes with OIDC on and `talos_inline_manifests`, two worker pools, load balancer, BGP neighbors with a `prefixes` entry carrying `le`, a plain and a NAT64 policy) was planned against mocked Netbox, Proxmox and FortiGate APIs and the plan turned into state, until the modules on `main` planned no changes against it. v0.1.0 with the caller edits of this guide was then planned against that state. The result is the table above, row for row.
- A module call that still passes `netbox` to one of the FortiGate-only modules was checked to fail as described under [Prerequisites](#prerequisites).
- The machine config was rendered locally with the Talos provider from the modules on `main` and from v0.1.0, for control planes and workers with OIDC on and off, with a non-default and an empty `oidc_groups_prefix`, an empty `oidc_username_prefix`, and with `talos_inline_manifests`. It differs in exactly the cases the table lists and is byte-identical for a control plane with OIDC on and default claims and prefixes.
- A new cluster with `node_keys` plans from an empty state, where no address is known. Removing the middle control plane and the middle worker of that cluster plans the destroy of those two nodes' resources and BGP neighbors, an in-place update of the three VIPs that removes one realserver, and no action on any other node or neighbor.
- The move of an existing control-plane pool to node keys plans as described under [Optional features](#optional-features-after-the-upgrade).
- State values that only exist after a real apply were made up for these plans. A provider that reports another value for an argument the modules do not set, or FortiOS behaving differently from the provider's plan, would not have shown up. The same goes for a deployment whose lock file holds older provider versions than the ones above.
