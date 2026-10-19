# Changelog

All notable changes to these modules are listed here. Versions are git tags; pin module sources with `?ref=<tag>`.

## v0.7.0 - 2026-10-19

A new module, `dns-records`, and two new outputs of `fg-vlan`. The other modules are unchanged: a plan shows no changes for unchanged inputs.

### Added

- `dns-records`: forward DNS record sets in one existing Poweradmin zone, one `poweradmin_rrset` per key of `records_by_key`. Names are fully qualified and written relative to `zone_name`; a name outside the zone, and two keys with the same name and type, are refused at plan time. The type is `AAAA` by default, and an `AAAA` value must be an IPv6 address, written in canonical form. The TTL is 300 seconds unless `ttl` or the record sets another. No reverse records: those come from automation in Netbox. Poweradmin replaces a whole record set on every write, so an existing record set with a name and type of the module is taken over on the first apply, without an import. New provider: `poweradmin/poweradmin` `~> 0.6.3`, which needs Poweradmin 4.1.0 or later and reads no environment variables. The module's tests run with the provider mocked; not applied to a running Poweradmin.
- `fg-vlan`: outputs `gateway_ip`, the gateway address without a prefix length, and `gateway_dns_name`, its DNS name in Netbox (null without `domain_name`), for the gateway's record in `dns-records`.
- `examples/full-cluster`: records for the API name, every node, the gateway and a CNAME, in a zone `domain_name` that is also the domain of the nodes and the gateway. The API name is in `extra_cert_sans` of the control plane.

## v0.6.0 - 2026-10-16

A new module, `keycloak-client`. The other modules are unchanged: a plan shows no changes for unchanged inputs.

### Added

- `keycloak-client`: one OpenID Connect client in an existing Keycloak realm, `PUBLIC` or `CONFIDENTIAL`, with the authorization code flow only and PKCE S256 by default. Its `client_id` output is `oidc.client_id` of `talos`, `client_secret` gives the secret of a confidential client and `keycloak_id` is Keycloak's ID of the client. An optional groups mapper (`groups_claim`) is for a realm without a default client scope `groups` like the one at The Gathering; Keycloak does not create that scope. `browser_flow` sets an authentication flow of the realm, by alias, as the client's browser flow override; null removes an override, so a client imported with one must set it, or the first apply opens it to every user of the realm. An existing client can be imported and keeps its secret: the first plan changes it in place to the module's settings, and also shows `use_refresh_tokens` going from `false` to `true` on a client that never had it set (no change in behaviour), possibly `backchannel_logout_session_required` going from `false` to `true` (no effect without a backchannel logout URL, which the module does not set) and `client_secret_wo` as a write-only attribute (not set by the module). New provider: `keycloak/keycloak` `~> 5.10`. The module's tests run with the provider mocked. By hand, against Keycloak 26.4 in a container with provider 5.10.0: creating clients, importing existing ones without a new secret, a clean plan after the apply, the `aud` and `groups` claims of the ID token, a provider client with `manage-clients` only, and `browser_flow`: an imported client with an override keeps it when the input is set, the plan after the apply is clean, and without the input the plan removes the override. The lookup of `browser_flow` needs `view-realm` as well: with `manage-clients` only, it fails with 403.
- `examples/full-cluster`: a client for the Kubernetes API, wired into `oidc` of the control plane.

## v0.5.0 - 2026-10-16

The module no longer changes the Kubernetes version of a running cluster, and `kubernetes_version` defaults to `v1.37.1`. A cluster that runs another version and uses the default fails its plan: upgrade it with `talosctl upgrade-k8s` first, or set `kubernetes_version` to the version it runs. Worker pools need the control-plane pool's `running_kubernetes_version` output to be checked, and the machine running OpenTofu needs tcp/6443 to the first control-plane node. Nothing else changes on an existing cluster.

### Added

- `talos`: the tests run `talosctl validate` on the rendered configs of a control plane with the defaults, a control plane with every option on, and workers. The Talos provider renders a config without validating it, so a patch that Talos rejects passed the tests before. `tofu test` in `talos` now needs `talosctl` on the `PATH`.
- `talos`: `kubelet_max_pods`, the most pods the kubelet runs on a node (`config.maxPods` of the `KubeletConfig` document), on control planes and workers. `null` by default, which leaves the kubelet default of 110 and changes nothing on an existing cluster. Setting it changes the machine config of every node of the pool, which is re-applied. Rendering is tested, and the same patch on a config from `talosctl gen config` passes `talosctl validate` for a control plane and a worker; not applied to a running cluster.

### Changed

- `talos`: the module no longer changes the Kubernetes version of a running cluster. A control-plane pool reads the version the cluster runs from the API (`/version` on the first control-plane node, with the client certificate of the kubeconfig), and the config apply refuses to run when `kubernetes_version` differs. On a running cluster the plan fails; only when the kubeconfig itself has a change pending is the version read during the apply, which then fails before any node gets the config. Upgrade with `talosctl upgrade-k8s`, one minor version at a time, then set `kubernetes_version` to the version the cluster runs. Worker pools are checked against the new `running_kubernetes_version` input: pass the control-plane pool's output of the same name. A new cluster needs nothing: the version is read during the apply, after the bootstrap. The machine running OpenTofu needs access to the API on the first control-plane node on tcp/6443; when the API cannot be reached the plan fails after 5 to 10 minutes of retries, and `skip_kubernetes_version_check = true` applies without the check. New provider: `hashicorp/http` `~> 3.6`. Tested with the API mocked; not tried on a running cluster.
- `talos`: `kubernetes_version` defaults to `v1.37.1`, the version Talos v1.14.2 ships, instead of `v1.35.5`. A running cluster that uses the default is refused until it runs that version: upgrade it first, or set `kubernetes_version` to the version it runs.

## v0.4.0 - 2026-10-12

A plan on an existing cluster shows the machine config of every control plane changing, for the metrics ports: the snippet files are replaced and the config is re-applied. Workers show no change. After it, every control plane serves the metrics of etcd, kube-controller-manager and kube-scheduler on all its addresses: check the firewall first, or turn them off with `etcd_listen_metrics_urls = []` and `null` for the two bind addresses.

### Added

- `talos`: `kubernetes_talos_api_access`, the roles and namespaces that pods may reach the Talos API with (`machine.features.kubernetesTalosAPIAccess`). Off by default and only applied through control planes. Setting it changes the machine config of every control plane, which is re-applied. Rendering is tested, and the same patch on a config from `talosctl gen config` passes `talosctl validate` for a control plane; not applied to a running cluster.
- `talos`: `etcd_listen_metrics_urls`, default `["http://[::]:2381"]`: etcd on the control planes serves `/metrics` and `/health` over plain HTTP on port 2381 of every address, IPv6 included (`cluster.etcd.extraArgs.listen-metrics-urls`). The port takes no client certificate: limit it in the firewall, or set `[]` to leave it off. On a running cluster the port may only open after a reboot of the control plane. Tested the same way, and not applied to a running cluster either.
- `talos`: `controller_manager_bind_address` and `scheduler_bind_address`, default `"::"`: kube-controller-manager (port 10257) and kube-scheduler (port 10259) on the control planes serve metrics on every address, IPv6 included, instead of 127.0.0.1 (`extraArgs.bind-address` of `KubeControllerManagerConfig` and `KubeSchedulerConfig`). `0.0.0.0` is IPv4 only and `null` leaves it to Talos; one address of the node is rejected, because Talos probes both on `localhost`. Tested the same way, and not applied to a running cluster either.

## v0.3.0 - 2026-10-10

`talos`: the machine config is built from the configuration documents of Talos 1.14. Nodes must run Talos 1.14 or later, and `talos_version` must be v1.14 or later: an older value is rejected at plan time. See [UPGRADING.md](./UPGRADING.md) before moving a running cluster.

A plan on an existing cluster shows the machine config of every node changing, workers included: the snippet files are replaced and the config is re-applied. Not applied to a running cluster: rendering is tested, and the result passes `talosctl validate`, which does not look at the content of the OIDC settings. Move a running cluster with `apply_mode = "staged"`.

### Added

- `talos`: `extra_cert_sans`, more names and addresses for the certificates of the Kubernetes API and the Talos API.
- `talos`: `oidc.cluster_admin_binding`, default `true`. `false` leaves the `ClusterRoleBinding` of `<cluster_name>-cluster-admin` out.

### Changed

- `talos`: `talos_version` defaults to `v1.14.2` and `kubernetes_version` to `v1.35.5`. Both were required.
- `talos`: OIDC is set up with the `KubeAuthenticationConfig` document. Talos owns the file, so turning OIDC on or changing `oidc` applies without a reboot. The file under `/var/lib/apiserver` of v0.2.0, its mount and the `authentication-config` argument are gone; v0.2.0 broke kube-apiserver when OIDC was applied to a running cluster, because Talos only writes such a file at boot.
- `talos`: the module's settings are patched in as one document each instead of one `machine`/`cluster` patch: `ResolverConfig`, `TimeSyncConfig`, `KubeNetworkConfig`, `DiscoveryServiceConfig`, `KubeAPIServerConfig`, `KubeNodeConfig`, `KubeAuthenticationConfig` and `KubeInlineManifestConfig`. kube-proxy and Flannel are left out by removing their documents. The `config_patches` output is a list of those patches.
- `talos`: with `allow_scheduling_on_control_planes`, a control plane also loses the `node.kubernetes.io/exclude-from-external-load-balancers` label, next to the `NoSchedule` taint. Before, the label stayed.
- `talos`: the KubePrism port is no longer set by the module. It is the Talos default, 7445, as before.
- `talos`: everything the module does not set is what Talos generates for the 1.14 contract. Compared to a v1.13 contract:
  - secure mount options on EPHEMERAL (`nosuid`, `nodev`), a weekly filesystem trim and workload isolation (`SecurityProfileConfig`) are added. The mount options and workload isolation take effect at the next boot.
  - kube-apiserver accepts anonymous requests on `/livez`, `/readyz` and `/healthz`. Before, it accepted none.
  - Secrets are read with the secretbox key only. Before, a Secret stored unencrypted was readable too.
  - `machine.install` becomes an `UnattendedInstallConfig` document, which does nothing on an installed node.

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
