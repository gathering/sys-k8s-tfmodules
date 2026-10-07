# Changelog

All notable changes to these modules are listed here. Versions are git tags; pin module sources with `?ref=<tag>`.

## v0.1.0 - unreleased

The first release meant to be pinned. It changes the interface of all five modules compared to `main` before it, which consumers tracked unpinned: every module call has to be edited, and after those edits a plan shows a fixed set of changes on every existing cluster. [UPGRADING.md](./UPGRADING.md) lists every edit, the expected plan and the rollout procedure. Anything else in the plan is a bug or a missed edit: do not apply it, report it.

The minimum OpenTofu version is 1.8. It cannot deprecate variables, so a renamed or removed input is an error until the call is edited, not a warning.

### Added

All modules:

- `required_version = ">= 1.8"` and provider version constraints: `bpg/proxmox ~> 0.116.0`, `e-breuninger/netbox ~> 5.8`, `siderolabs/talos ~> 0.12.0`, `fortinetdev/fortios ~> 1.26`, `hashicorp/random ~> 3.9`. `talos` declares `hashicorp/random`, which it already used.
- `tofu test` tests in every module. Netbox, Proxmox and FortiGate are mocked, so they need no credentials.
- CI on pull requests and pushes to `main` (fmt, validate, test, tflint, terraform-docs check) with matching pre-commit hooks.
- [`examples/full-cluster`](./examples/full-cluster), a root module that wires all five modules and is validated in CI.
- This changelog and [UPGRADING.md](./UPGRADING.md). The root README documents how the modules fit together, the naming conventions and versioning.

`talos`:

- `node_keys` and the `nodes_by_key` output. A pool with `node_keys` names each node `<node_prefix><key>` and tracks it by that key, so any node can be removed without touching the others. Without it a pool works as before, with random names, tracked by position and with the same resource addresses.
- `apply_mode`, passed to every config apply. See "Changed" for the default.
- `on_destroy`, default `{ graceful = true, reset = false, reboot = false }`: a removed node's VM is deleted without telling Talos, as before. `on_destroy = { reset = true }` resets a node before it is removed, so that a removed control plane leaves etcd instead of staying behind as a dead member.
- `snippet_per_pool` names the machine config snippet per pool, so that pools of the same type in one cluster stop overwriting each other's file. Off by default; see the README before turning it on for an existing pool.
- `proxmox_nodes` pins the hosts that get the snippet and the placement order. `proxmox_online_only` skips offline hosts when placing new VMs.
- `netbox_node_prefix_lookup` looks up the prefix id from `netbox_node_prefix`; `netbox_node_prefix_id` is optional when it is set.
- `gateway` overrides the default of host 1 of the node prefix.
- `template_vm_id`, `template_node_name`, `snippet_datastore`, `on_boot`, `agent_enabled`, `tags` and `description` replace literals. The defaults are the values that were hardcoded.

`fg-k8slb`:

- `realservers_by_key` takes the realservers with explicit ids, so that a membership change does not renumber the others.
- `ssl_ssh_profile`, default `SSL-Monitor` as hardcoded before.
- Outputs `vip_names` and `policy_id`.

`fg-policy`:

- `ssl_ssh_profile` and `nat64_pool`, with the previously hardcoded values as defaults.
- `comments`, `nat` and a null `nat64`, to leave those arguments unset on the policy. The defaults give the policy the module created before.
- Output `policy_id`.

`fg-bgp-neighbors`:

- `neighbors_by_key` tracks neighbors by key. It can be combined with `neighbors`.
- Optional `le` and `id` on `prefixes` entries; `ge` is optional. `id` sets the prefix-list rule id, so that an entry can be removed or inserted without renumbering the others.
- `prefix_list_name` renames the prefix lists for a second instance of the module in one cluster.
- Outputs `neighbor_ips`, `neighbor_ips_by_key`, `prefix_list_in_name` and `prefix_list_out_name`.

### Changed

`talos`:

- `pod_subnets` and `service_subnets` are required and must be non-empty lists of CIDR prefixes. The old default `[]` made Talos render a cluster without pod and service networks.
- Input `netbox_cluster` is now `netbox_cluster_name`; input `netbox_device_role` is now `netbox_device_role_name`; output `name` is now `cluster_name`.
- Config changes are applied with `apply_mode = "staged_if_needing_reboot"` by default instead of the provider default `auto`. On nodes running Talos before 1.14, a config change that needs a reboot is staged instead of rebooting every node of the pool at once. Talos 1.14 and later do not reboot on a config apply.
- Workers get a machine config without the settings only control planes act on: `apiServer` (with the OIDC arguments), `allowSchedulingOnControlPlanes`, `inlineManifests`, `proxy` and `network.cni`.
- Control planes get one config patch instead of two. The `controlplane_config_patches` output has one element; `worker_config_patches` loses the control-plane settings.
- The OIDC `ClusterRoleBinding` is only rendered with OIDC on.
- OIDC is off when `oidc_issuer_url` is `null` as well as when it is `""`. `oidc_issuer_url` and `oidc_client_id` default to `null`. Every `oidc_*` input accepts `null` and `""` for unset, and an unset input is left out of the API server arguments.
- `oidc_issuer_url` without `oidc_client_id` is rejected at plan time. kube-apiserver refuses to start with only one of the two.
- `talos_machine_secrets`, `talos_client_configuration`, `pod_subnets`, `service_subnets` and `talos_inline_manifests` have types. `talos_machine_secrets` is marked sensitive. `talos_inline_manifests` is a list of objects with `name` and `contents`; any other attribute on an entry is dropped.
- Input validation: `type` must be `controlplane` or `worker`, `nodes` a whole number of 0 or more, `cluster_name` not empty, `node_prefix` made of letters, digits, hyphens and dots. A control-plane pool must have at least one node.
- The `nodes` output is built from the Netbox records instead of the Proxmox VM state. Same values; it no longer waits for the VMs to be created.
- VM placement wraps around when a pool has more nodes than there are Proxmox hosts instead of failing. Existing VMs do not move.
- Every config apply is ordered after all VMs of the pool and the bootstrap explicitly.
- Node addresses are derived by splitting off the prefix length instead of trimming a literal `/64`. Same result for `/64` prefixes.

`fg-k8slb`:

- Input `name` is now `cluster_name`. Input `dstintf` is a list of strings.
- `realservers` is optional; exactly one of `realservers` and `realservers_by_key` must be set.
- The three VIPs are one resource with `for_each`, and the policy is created through the `fg-policy` module instead of a resource of its own. `moved` blocks carry the state over; VIPs and policy are unchanged.

`fg-policy`:

- Inputs `srcintf` and `dstintf` are lists of strings, with at least one entry.

`fg-bgp-neighbors`:

- `prefixes` is required and must not be empty: an inbound prefix list without rules rejects every route from the cluster.
- `remote_as` is a string, default `"64513"`. A number in a module call is still accepted and gives the same value.
- `neighbors` is optional and defaults to `[]`.

`fg-vlan`:

- Input `vlan_group` is now `netbox_vlan_group_name`; input `base_prefix` is now `netbox_base_prefix`.
- Output `vlan_name` is now `interface_name`; output `name` is now `netbox_vlan_name`; output `vlan_id` is now `vlan_vid`. Same values.
- `name` is limited to 25 characters, the limit of the FortiGate interface alias it becomes.

All modules:

- File layout: `terraform.tf` is now `versions.tf`; `talos` has one file per provider; `fg-k8slb/policy.tf` is merged into `main.tf`.
- Descriptions and READMEs corrected, including the meaning of `talos_version`, the `fg-vlan` outputs and the `talos` prerequisites. README examples pin the module source to a tag.

### Removed

- `fg-vlan`: the unused inputs `infra_zone` and `bastion_address_group`.
- `fg-bgp-neighbors`, `fg-k8slb` and `fg-policy`: the unused `netbox` provider requirement.
- `talos`: commented-out `local_file` resources.

### Fixed

- `talos`: the OIDC `ClusterRoleBinding` names the group with `oidc_groups_prefix` in front instead of a fixed `oidc:`, so it matches the group kube-apiserver sees when the prefix is not the default.
- `talos`: with OIDC on, an `oidc_*` input set to `""` or `null` was rendered as an API server argument with a null value.
- `fg-bgp-neighbors`: an `le` key on a `prefixes` entry was dropped. It is applied now.

### Upgrade notes

The guide is [UPGRADING.md](./UPGRADING.md). In short, for a deployment that tracks `main` from before this release:

- Every module call needs edits: renamed inputs and outputs in `fg-vlan`, `talos` and `fg-k8slb`, strings that became lists in `fg-k8slb` and `fg-policy`, and inputs that became required in `talos` and `fg-bgp-neighbors`.
- After the edits and with nothing new turned on, the plan updates every `talos_machine_configuration_apply` in place, replaces the snippet files of every pool whose rendered config changes (all worker pools, and control-plane pools with OIDC off or with non-default OIDC prefixes or claims), and moves the three VIPs and the policy of every `fg-k8slb` instance without changing them. No Netbox resource, `random_id`, VM, bootstrap or kubeconfig changes.
- The apply contacts every node on tcp/50000. Do it in a maintenance window, test cluster first, control planes first.
- The `moved` blocks in `fg-k8slb` exist for this upgrade and may be removed in a later release, once consumers have applied v0.1.0.
- `talos_client_configuration` is deliberately not marked sensitive: doing so plans an in-place update of every Talos resource on existing clusters.

None of this was run against real Netbox, Proxmox, Talos or FortiGate. UPGRADING.md says how the expected plan was produced.

## v0.0.1

Initial tag.
