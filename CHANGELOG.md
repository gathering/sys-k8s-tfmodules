# Changelog

All notable changes to these modules are listed here. Versions are git tags; pin module sources with `?ref=<tag>`.

## v0.3.0 - 2026-10-10

`talos`: the machine config is built from the configuration documents of Talos 1.14. Nodes must run Talos 1.14 or later, and `talos_version` must be v1.14 or later: an older value is rejected at plan time. See [UPGRADING.md](./UPGRADING.md) before moving a running cluster.

A plan on an existing cluster shows the machine config of every node changing, workers included: the snippet files are replaced and the config is re-applied. Not applied to a running cluster: rendering is tested, and the result passes `talosctl validate`.

### Changed

- `talos`: `talos_version` defaults to `v1.14.2` and `kubernetes_version` to `v1.35.5`. Both were required.
- `talos`: OIDC is set up with the `KubeAuthenticationConfig` document. Talos owns the file, so turning OIDC on or changing `oidc` applies without a reboot. The file under `/var/lib/apiserver` of v0.2.0, its mount and the `authentication-config` argument are gone; v0.2.0 broke kube-apiserver when OIDC was applied to a running cluster, because Talos only writes such a file at boot.
- `talos`: the module's settings are patched in as one document each instead of one `machine`/`cluster` patch: `ResolverConfig`, `TimeSyncConfig`, `KubePrismConfig`, `KubeNetworkConfig`, `DiscoveryServiceConfig`, `KubeAPIServerConfig`, `KubeNodeConfig`, `KubeAuthenticationConfig` and `KubeInlineManifestConfig`. kube-proxy and Flannel are left out by removing their documents. The `config_patches` output is a list of those patches.
- `talos`: everything the module does not set is what Talos generates for the 1.14 contract. Compared to a v1.13 contract that adds secure mount options on EPHEMERAL (`nosuid`, `nodev`), a weekly filesystem trim and workload isolation (`SecurityProfileConfig`).

### Removed

- `talos`: support for a `talos_version` before v1.14.

## v0.2.0 - 2026-10-10

A plan on a cluster with `oidc` set shows the machine config of every control plane changing: the snippet files are replaced and the config is re-applied. Workers and clusters without `oidc` show no change apart from `extraArgs: {}` leaving the control-plane config.

The new config needs a reboot, because Talos writes the file at boot only:

- On nodes running Talos before 1.14, the default `apply_mode` stages the change. Reboot the control planes one at a time; each moves to the file when it comes back, and uses the `--oidc-*` arguments until then.
- On nodes running Talos 1.14 or later, set `apply_mode = "staged"` on the control-plane pool for this change, and reboot the control planes one at a time. With the default, the API server argument is applied at once and the file is not there until the reboot: kube-apiserver does not start on any control plane. Read from the Talos source, not tested.

### Added

- `talos`: `oidc.audiences`, more audiences to accept tokens for next to `client_id`.

### Changed

- `talos`: OIDC is set up in an `AuthenticationConfiguration` file, `/var/lib/apiserver/authentication.yaml` on the control planes, instead of with the `--oidc-*` arguments of kube-apiserver. It needs Kubernetes 1.34 or later. Users, groups and the cluster-admin binding are the same as before with the default claims and prefixes.
- `talos`: `oidc.username_claim` must be set; `""` is rejected. `username_prefix = ""` now means no prefix: the arguments put the issuer URL in front instead. A `username_claim` of `email` no longer requires `email_verified`.

## v0.1.1 - 2026-10-09

A plan on an existing deployment shows in-place updates only: `dns_name` on every node address and every gateway address, the VM description, and the comments on the FortiGate objects. Where DNS is generated from Netbox, as at The Gathering, the `dns_name` values become DNS records.

### Added

- `talos`: every node address gets a `dns_name` in Netbox, `<node_prefix><key>.<domain_name>`. A plan shows an in-place update of each node address (`dns_name` `""` -> `<node>.<domain>`) and nothing else.
- `fg-vlan`: the gateway address gets a `dns_name` in Netbox, `gw.<name>.<domain_name>`, with the new input `domain_name` (default `gathering.systems`). A plan shows an in-place update of the gateway address. `name` is part of that DNS name: a `name` with spaces or other characters Netbox does not accept in a DNS name is rejected at plan time. Set `domain_name = null` to leave such a VLAN's gateway without a DNS name.
- `fg-k8slb`: the three VIPs get a comment naming the API and the cluster.
- `talos`: output `machine_configuration`, the rendered machine config of the pool, sensitive.
- `talos`, `fg-vlan`: `domain_name` must be a DNS domain.

### Changed

- FortiGate comments say what an object is for instead of `<name> - Created by Terraform Provider for FortiOS`. A plan shows an in-place update of each:
  - `fg-vlan`: interface `<name> (VLAN <vid>). Managed by OpenTofu`, address object `Prefix of <name> (VLAN <vid>). Managed by OpenTofu`.
  - `fg-bgp-neighbors`: prefix lists `Prefixes accepted from Kubernetes cluster <cluster_name>. Managed by OpenTofu` and `Nothing is advertised to Kubernetes cluster <cluster_name>. Managed by OpenTofu`. The neighbor descriptions are unchanged.
  - `fg-policy`: the default comment is `Managed by OpenTofu`; set `comments` to say what the policy is for.
  - `fg-k8slb`: the policy comment is `Kubernetes and Talos API of cluster <cluster_name>. Managed by OpenTofu`.

- `talos`: the default VM `description` names the cluster and the node type, `Talos <type> node of Kubernetes cluster <cluster_name>. Managed by OpenTofu: changes made here are overwritten.`, instead of `Managed by Undercloud (Terraform)`. A plan shows an in-place update of the description on every VM that uses the default. `description` still overrides it.

### Fixed

- `talos`: a change pending on a resource the machine config is built from, such as an in-place update of the cluster address, no longer replaces every snippet file and re-applies the config on every node, as long as the value the config uses is known at plan time. A value that is only known after apply, such as a prefix allocated in the same run, still does. The precondition that rejects an empty control-plane pool made OpenTofu read the machine configuration during apply; it is now on the `cluster_name` output. An empty control-plane pool still fails at plan time, with the same message.

## v0.1.0 - 2026-10-09

The first release meant to be pinned. It changes the interface of all five modules compared to `main` before it, which consumers tracked unpinned, and it tracks nodes by key instead of by position. There is no in-place upgrade from the modules before it: clusters are redeployed, see [UPGRADING.md](./UPGRADING.md).

The minimum OpenTofu version is 1.8. It cannot deprecate variables, so a renamed or removed input is an error until the call is edited, not a warning.

### Added

All modules:

- `required_version = ">= 1.8"` and provider version constraints: `bpg/proxmox ~> 0.116.0`, `e-breuninger/netbox ~> 5.8`, `siderolabs/talos ~> 0.12.0`, `fortinetdev/fortios ~> 1.26`.
- `tofu test` tests in every module. Netbox, Proxmox and FortiGate are mocked, so they need no credentials.
- CI on pull requests and pushes to `main` (fmt, validate, test, tflint, terraform-docs check) with matching pre-commit hooks.
- [`examples/full-cluster`](./examples/full-cluster), a root module that wires all five modules and is validated in CI.
- This changelog and [UPGRADING.md](./UPGRADING.md). The root README documents how the modules fit together, the naming conventions and versioning.

`talos`:

- `node_keys`, required, and the `nodes_by_key` output. Each node is named `<node_prefix><key>` and tracked by that key, so any node can be removed without touching the others. It replaces `nodes` and the random node names, see "Removed".
- `apply_mode`, passed to every config apply. See "Changed" for the default.
- `on_destroy`, default `{ graceful = true, reset = false, reboot = false }`: a removed node's VM is deleted without telling Talos, as before. `on_destroy = { reset = true }` resets a node before it is removed, so that a removed control plane leaves etcd instead of staying behind as a dead member.
- `proxmox_nodes` pins the hosts that get the snippet and the placement order. `proxmox_online_only` skips offline hosts when placing new VMs.
- `netbox_node_prefix_lookup` looks up the prefix id from `netbox_node_prefix`; `netbox_node_prefix_id` is optional when it is set.
- `gateway` overrides the default of host 1 of the node prefix.
- `template_vm_id`, `template_node_name`, `snippet_datastore`, `on_boot`, `agent_enabled`, `tags` and `description` replace literals. The defaults are the values that were hardcoded.

`fg-k8slb`:

- `realservers_by_key`, required and not empty, takes the realservers with explicit ids, so that a membership change does not renumber the others. It replaces `realservers`, see "Removed".
- `ssl_ssh_profile`, default `SSL-Monitor` as hardcoded before.
- Outputs `vip_names` and `policy_id`.

`fg-policy`:

- `ssl_ssh_profile` and `nat64_pool`, with the previously hardcoded values as defaults.
- `comments` overrides the default comment. `nat` sets source NAT; null, the default, leaves it unset on the policy.
- Output `policy_id`.

`fg-bgp-neighbors`:

- `neighbors_by_key`, required, tracks neighbors by key. It replaces `neighbors`, see "Removed".
- Optional `le` and `id` on `prefixes` entries; `ge` is optional. `id` sets the prefix-list rule id, so that an entry can be removed or inserted without renumbering the others.
- `prefix_list_name` renames the prefix lists for a second instance of the module in one cluster.
- Outputs `neighbor_ips_by_key`, `prefix_list_in_name` and `prefix_list_out_name`.

### Changed

All modules:

- Every variable is `nullable = false` unless its default is null: passing `null` gives the default instead of overriding it with null, and `null` for a required input is rejected.

`talos`:

- `pod_subnets` and `service_subnets` are required and must be non-empty lists of CIDR prefixes. The old default `[]` made Talos render a cluster without pod and service networks.
- Input `netbox_cluster` is now `netbox_cluster_name`; input `netbox_device_role` is now `netbox_device_role_name`; output `name` is now `cluster_name`.
- The machine config snippet is named `<cluster_name>-<type>-<node_prefix>.yaml` instead of `<cluster_name>-<type>.yaml`, so that pools of the same type in one cluster no longer overwrite each other's file. `node_prefix` must not be empty and is used as given: `wa-` and `wa` are different pools.
- A pool without nodes uploads no snippet: the machine config holds the cluster secrets.
- Config changes are applied with `apply_mode = "staged_if_needing_reboot"` by default instead of the provider default `auto`. On nodes running Talos before 1.14, a config change that needs a reboot is staged instead of rebooting every node of the pool at once. Talos 1.14 and later do not reboot on a config apply.
- Workers get a machine config without the settings only control planes act on: `apiServer` (with the OIDC arguments), `allowSchedulingOnControlPlanes`, `inlineManifests`, `proxy` and `network.cni`.
- Control planes get one config patch instead of two. The outputs `controlplane_config_patches` and `worker_config_patches` are replaced by `config_patches`, the one patch of the pool's own type.
- The OIDC `ClusterRoleBinding` is only rendered with OIDC on.
- The six `oidc_*` inputs are one optional object, `oidc`, with `issuer_url` and `client_id` required and the claims and prefixes optional. OIDC is off when it is null, the default. A claim or prefix set to `""` is left out of the API server arguments; `null` gives its default.
- `talos_machine_secrets`, `talos_client_configuration`, `pod_subnets`, `service_subnets` and `talos_inline_manifests` have types. `talos_machine_secrets` is marked sensitive. `talos_inline_manifests` is a list of objects with `name` and `contents`, both required; any other attribute on an entry is dropped.
- Input validation: `type` must be `controlplane` or `worker`, `cluster_name` not empty, `node_prefix` not empty and made of letters, digits, hyphens and dots. A control-plane pool must have at least one node.
- VM placement wraps around when a pool has more nodes than there are Proxmox hosts instead of failing.
- Every config apply is ordered after all VMs of the pool and the bootstrap explicitly.
- Node addresses are derived by splitting off the prefix length instead of trimming a literal `/64`. Same result for `/64` prefixes.

`fg-k8slb`:

- Input `name` is now `cluster_name`. Input `dstintf` is a list of strings.
- The three VIPs are one resource with `for_each`, and the policy is created through the `fg-policy` module instead of a resource of its own. The policy now gets that module's default comment and `nat64` and `ippool` set to `disable`.

`fg-policy`:

- Inputs `srcintf` and `dstintf` are lists of strings, with at least one entry.

`fg-bgp-neighbors`:

- `prefixes` is required and must not be empty: an inbound prefix list without rules rejects every route from the cluster.
- `remote_as` is a string, default `"64513"`. A number in a module call is still accepted and gives the same value.

`fg-vlan`:

- Input `vlan_group` is now `netbox_vlan_group_name`; input `base_prefix` is now `netbox_base_prefix`.
- Output `vlan_name` is now `interface_name`; output `name` is now `netbox_vlan_name`; output `vlan_id` is now `vlan_vid`. Same values.
- `name` is limited to 25 characters, the limit of the FortiGate interface alias it becomes.

All modules:

- File layout: `terraform.tf` is now `versions.tf`; `talos` has one file per provider; `fg-k8slb/policy.tf` is merged into `main.tf`.
- Descriptions and READMEs corrected, including the meaning of `talos_version`, the `fg-vlan` outputs and the `talos` prerequisites. README examples pin the module source to a tag.

### Removed

- `talos`: `nodes`, the random node names and the `hashicorp/random` provider. Nodes are no longer tracked by position; `node_keys` is the only way to size a pool.
- `talos`: the list outputs `nodes` and `nodes_ip`. Use `nodes_by_key`, for example `values(module.<pool>.nodes_by_key)[*].ip`.
- `fg-bgp-neighbors`: the list input `neighbors`. Use `neighbors_by_key`.
- `fg-k8slb`: the list input `realservers`. Use `realservers_by_key`.
- `fg-vlan`: the unused inputs `infra_zone` and `bastion_address_group`.
- `fg-bgp-neighbors`, `fg-k8slb` and `fg-policy`: the unused `netbox` provider requirement.
- `talos`: commented-out `local_file` resources.

### Fixed

- `talos`: the OIDC `ClusterRoleBinding` names the group with the OIDC groups prefix in front instead of a fixed `oidc:`, so it matches the group kube-apiserver sees when the prefix is not the default.
- `talos`: with OIDC on, a claim or prefix set to `""` was rendered as an API server argument with a null value.
- `fg-bgp-neighbors`: an `le` key on a `prefixes` entry was dropped. It is applied now.

### Upgrade notes

There is no in-place upgrade from `main` before this release; redeploy, see [UPGRADING.md](./UPGRADING.md).

Not run against real Netbox, Proxmox, Talos or FortiGate in this form: the tests mock them. What `apply_mode` does on running nodes, removing the first control-plane key and reset on destroy are read from the provider source and not tested; the READMEs mark them.

## v0.0.1

Initial tag.
