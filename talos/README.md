# TG Talos (k8s) Terraform Module

Provisions a group of Talos Kubernetes nodes (controlplane or worker) on Proxmox, registers each node in Netbox with an allocated IPv6 address, and applies Talos machine configuration. When `type = "controlplane"`, also bootstraps etcd and retrieves the kubeconfig.

## Prerequisites

- A Talos machine secrets object and client configuration (created once per cluster, outside this module)
- A Netbox IPv6 prefix to allocate node IPs from
- A Proxmox template VM to clone from (`template_vm_id` on `template_node_name`, default `9201` on `pve1`). Every VM create needs that host to be up
- A datastore with the `snippets` content type on every Proxmox host (`snippet_datastore`, default `local`). The full machine config, secrets included, is stored there in plaintext
- The machine running OpenTofu needs direct access to the node addresses on tcp/50000. Bootstrap, config apply and the kubeconfig go to a node IP, not through the load balancer
- Worker pools join through the cluster endpoint. Their config apply retries until the control plane answers; to order it explicitly, apply the control-plane module first (`-target=module.controlplane`). Do not put a module-level `depends_on` on this module, see [below](#module-level-depends_on)
- Talos 1.14 or later on the nodes, in the template included
- The module leaves out the CNI and kube-proxy. Install a CNI with kube-proxy replacement after bootstrap; nodes stay `NotReady` until then

`talos_version` is the version contract the machine config is generated for, `v1.14.2` by default and v1.14 at the least: the config is built from the configuration documents Talos 1.14 introduced. It does not install or upgrade Talos; upgrades happen outside this module. The nodes must run at least that version. `kubernetes_version` defaults to `v1.35.5`.

## Usage

```hcl
module "controlplane" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//talos?ref=v0.3.0"

  cluster_name               = "my-cluster"
  node_prefix                = "my-cluster-cp-"
  type                       = "controlplane"
  node_keys                  = ["a", "b", "c"]
  cluster_ip                 = "2001:db8::1"
  talos_machine_secrets      = talos_machine_secrets.this.machine_secrets
  talos_client_configuration = talos_machine_secrets.this.client_configuration
  pod_subnets                = ["2001:db8:1000::/56"]
  service_subnets            = ["2001:db8:1000:100::/112"]
  netbox_node_prefix         = "2001:db8::/64"
  netbox_node_prefix_id      = 42
  node_vlan_vid              = 100
  netbox_site_id             = 1
}
```

A complete cluster with all five modules is in [`examples/full-cluster`](../examples/full-cluster).

## Node keys

`node_keys` has one key per node. A node is named `<node_prefix><key>`, for example `my-cluster-cp-a`, its address gets the DNS name `<node_prefix><key>.<domain_name>` in Netbox, and every per-node resource is tracked by that key (`...this["a"]`).

- The list must be known at plan time: write the keys out, do not derive them from a resource.
- A key is part of the hostname and never changes for a node. Adding a key adds a node; removing a key destroys that node's VM, Netbox records and address, and nothing of the other nodes. Reordering the list changes nothing on existing nodes.
- Keys and names in `nodes_by_key` are known at plan time, the addresses only after the first apply. That is what lets `fg-bgp-neighbors` (`neighbors_by_key`) and `fg-k8slb` (`realservers_by_key`) track their entries by key as well.
- Bootstrap and kubeconfig go to the first node in `node_keys`. Removing that node or putting another one first updates `talos_machine_bootstrap` and `talos_cluster_kubeconfig` in place to the new first node. For the bootstrap that only records the new address; nothing is bootstrapped again (read in the source of talos provider 0.12.0, not run against a cluster).
- A worker pool may be empty (`node_keys = []`); it then creates nothing, not even the snippet. Do not empty a control-plane pool; remove the module instead.

## Placement

By default the machine config snippet is uploaded to every Proxmox host the API returns, and node N of `node_keys` is created on host N in API order, wrapping around when the pool is larger than the host count. N is the position of the key in the list at the time the VM is created.

- `proxmox_online_only = true` skips offline hosts when placing new VMs. The snippet still goes to every host.
- `proxmox_nodes = ["pve1", "pve2"]` pins both the snippet hosts and the placement order, and the module no longer asks Proxmox for its hosts. The list must be known at plan time, so write it out instead of deriving it from a resource.

Neither moves an existing VM: `node_name` is ignored after create, so VMs can be migrated freely. A VM does need the snippet on the host it starts on. Removing a host from `proxmox_nodes` deletes the snippet there, and a VM on that host then fails its next start, so only leave out hosts that run no nodes of the pool and are not migration targets.

## Node prefix and gateway

Node addresses are allocated from the Netbox prefix given in one of two ways:

- `netbox_node_prefix_id`: use this when the prefix is created in the same configuration, for example `module.vlan.prefix_id` from `fg-vlan`. It works on the first apply, when the prefix does not exist yet.
- `netbox_node_prefix_lookup = true`: looks the id up from `netbox_node_prefix`. Use this only for a prefix that exists in Netbox before the plan and is unique there. If the lookup cannot run during the plan, the id is unknown until apply, and for an existing pool OpenTofu then plans to replace every node address.

Do not switch an existing pool between the two unless both give the same id: a different id replaces the addresses.

`gateway` defaults to host 1 of `netbox_node_prefix`. It is part of the VM's cloud-init data, so changing it only affects VMs created afterwards.

## Snippet name

The machine config of a pool is one snippet file per Proxmox host, named `<cluster_name>-<type>-<node_prefix>.yaml`, for example `my-cluster-worker-my-cluster-w-.yaml`. Pools of one cluster therefore need different prefixes, or they overwrite each other's file.

A pool without nodes uploads no snippet, so an empty worker pool does not put the machine config, with its cluster secrets, on the hosts.

A VM stores the snippet name in its Proxmox config (`cicustom`) and Proxmox reads the file on every start of the VM. The module never updates that reference: `initialization` is ignored after create, since changing it re-runs cloud-init. Do not change `cluster_name`, `type` or `node_prefix` of a pool with nodes.

Any change to the rendered machine config replaces the files under the same name: the provider deletes and uploads again. A VM that starts on that host in between fails to start and can be started again afterwards.

## Config changes and reboots

`apply_mode` is passed to every `talos_machine_configuration_apply`. Talos 1.14 does not reboot on a config apply: the config is applied live, and whatever needs a reboot takes effect at the next reboot. So the module does not reboot a node whatever the mode, and the default `staged_if_needing_reboot` applies live. `apply_mode = "staged"` applies nothing live: the whole change waits for the reboot. This is read from the Talos source and release notes, not tested. Reboot one node at a time and wait for it to be healthy, control planes first:

```sh
talosctl -n <node> reboot
talosctl -n <node> health
```

Read the plan warnings before applying:

- `Cannot check reboot requirement`: the node could not be reached during the plan. Fix the access and plan again before applying.
- `staged_if_needing_reboot is not supported on Talos 1.14+`: expected, see above.

The apply itself, not only the plan, contacts nodes on tcp/50000. When a config apply is updated for any reason, the provider sends the config to that node again, also when the config itself is unchanged, and retries for up to 10 minutes (read in the provider source, not tested). One node being down therefore fails the apply.

Config applies of one pool run in parallel. For a change that touches the control planes, apply with `-parallelism=1` and, in a cluster with several pools, the control-plane module first (`-target=module.controlplane`). Changes outside that module then show up in the second, untargeted apply, which is expected. A new node boots with the config from the snippet, so its first config apply changes nothing whatever the mode.

## Removing nodes

`on_destroy` controls what happens when a node leaves the pool, by removing its key from `node_keys` or removing the module. The default (`graceful = true, reset = false, reboot = false`) does not reset the node: the VM and the Netbox records are deleted without telling Talos, and a removed control plane stays in etcd as a dead member until it is removed by hand (`talosctl etcd remove-member`).

Set `on_destroy = { reset = true }` to reset the node first: it is cordoned and drained, a control plane leaves etcd, its STATE and EPHEMERAL partitions are wiped and it halts. Then the VM and the Netbox records are deleted. With reset on:

- The setting is read from state, not from the configuration. It has to be applied (`tofu apply`) before the scale-down it should affect.
- The reset needs the node to answer on tcp/50000. Destroying a node that is down blocks for the timeout (10 minutes) and then fails. Take that node's config apply out of state and apply again: `tofu state rm 'module.<pool>.talos_machine_configuration_apply.this["<key>"]'`. Then remove its etcd member by hand.
- A graceful reset cannot remove the last etcd member. Before destroying a whole cluster, set `on_destroy = { reset = false }` on all pools and apply, then destroy.

Either way the Kubernetes `Node` object stays; delete it with `kubectl delete node <name>`.

## OIDC

OIDC is on when `oidc` is set; `issuer_url` and `client_id` are required in it:

```hcl
oidc = {
  issuer_url = "https://sso.example.org/realms/my-realm"
  client_id  = "kubernetes"
}
```

`audiences` lists more audiences to accept tokens for, next to `client_id`: the client of a dashboard that passes the token of its user on to the API server, for example.

```hcl
oidc = {
  issuer_url = "https://sso.example.org/realms/my-realm"
  client_id  = "kubernetes"
  audiences  = ["kubernetes-dashboard"]
}
```

The claims and prefixes (`username_claim`, `username_prefix`, `groups_claim`, `groups_prefix`) have defaults. Set `groups_claim` to `""` to give the users no groups, and a prefix to `""` for no prefix.

OIDC is set up with the `KubeAuthenticationConfig` document of Talos, which becomes the [`AuthenticationConfiguration`](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#using-authentication-configuration) of kube-apiserver. Talos writes the file and points kube-apiserver at it, so turning OIDC on or changing `oidc` needs no reboot. Anonymous requests are accepted on the health endpoints only (`/livez`, `/readyz`, `/healthz`), as Talos sets it up without OIDC.

With OIDC on, the control planes also get a `ClusterRoleBinding` that makes the group `<cluster_name>-cluster-admin` of the identity provider cluster admin. The binding names the group as kube-apiserver sees it, with `groups_prefix` in front: `oidc:<cluster_name>-cluster-admin` by default. With OIDC off there is no binding, and `cluster_admin_binding = false` in `oidc` leaves it out, for a cluster that manages its role bindings itself. Without a binding, a user who logs in through OIDC has no access.

Talos creates the objects of an inline manifest when they are missing and leaves existing ones alone. After changing `groups_prefix` or turning OIDC off on a running cluster, delete the old binding yourself: `kubectl delete clusterrolebinding oidc-<cluster_name>-cluster-admin`. The same goes for `talos_inline_manifests`.

## Machine config patches

The config is the one Talos generates for `talos_version`, with one patch per configuration document on top:

| Document | Nodes | What the module sets |
|---|---|---|
| `machine` (v1alpha1) | all | `certSANs`: `localhost`, `cluster_ip` and `extra_cert_sans` |
| `ResolverConfig` | all | `nameservers` |
| `TimeSyncConfig` | all | `time_servers` |
| `KubeNetworkConfig` | all | `pod_subnets` and `service_subnets` |
| `DiscoveryServiceConfig` | all | `discovery_service_endpoint`, or removed with `discovery_enabled = false` |
| `KubeAPIServerConfig` | control planes | `certExtraSANs`: `localhost`, `cluster_ip` and `extra_cert_sans` |
| `KubeProxyConfig`, `KubeFlannelCNIConfig` | control planes | removed: the cluster brings its own CNI |
| `KubeNodeConfig` | control planes | with `allow_scheduling_on_control_planes`: no `NoSchedule` taint and no `exclude-from-external-load-balancers` label |
| `KubeAuthenticationConfig` | control planes | OIDC, with `oidc` |
| `KubeInlineManifestConfig` | control planes | the OIDC binding, then `talos_inline_manifests` |

KubePrism is on, on port 7445: the Talos default.

Everything else is also what Talos generates. The `config_patches` output is the list of patches of the pool's own type.

## Module-level depends_on

`depends_on` on the module block makes OpenTofu read every data source in the module during apply whenever the dependency has changes pending. With the default host lookup the snippet `for_each` then cannot be planned at all. With `proxmox_nodes` set it plans, but each such plan still shows the machine config as unknown, which replaces the snippet files and re-applies the config, and with `netbox_node_prefix_lookup` it would replace the node addresses. Order pools with `-target` instead.

## Tests

`tofu test` in this directory runs the tests in [`tests`](./tests). Netbox and Proxmox are mocked, so no credentials are needed; the Talos provider renders the machine config locally. The mocks cannot show whether a plan leaves a resource alone, only which resources exist and how they are configured.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_netbox"></a> [netbox](#requirement\_netbox) | ~> 5.8 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.116.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.12.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_netbox"></a> [netbox](#provider\_netbox) | ~> 5.8 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | ~> 0.116.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | ~> 0.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [netbox_available_ip_address.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/available_ip_address) | resource |
| [netbox_interface.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/interface) | resource |
| [netbox_primary_ip.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/primary_ip) | resource |
| [netbox_virtual_machine.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/resources/virtual_machine) | resource |
| [proxmox_virtual_environment_file.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_file) | resource |
| [proxmox_virtual_environment_vm.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [netbox_cluster.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/data-sources/cluster) | data source |
| [netbox_device_role.this](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/data-sources/device_role) | data source |
| [netbox_prefix.node](https://registry.terraform.io/providers/e-breuninger/netbox/latest/docs/data-sources/prefix) | data source |
| [proxmox_virtual_environment_nodes.available_nodes](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_nodes) | data source |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_agent_enabled"></a> [agent\_enabled](#input\_agent\_enabled) | Enable the QEMU guest agent. The template needs the qemu-guest-agent extension, otherwise every VM create waits for the agent timeout | `bool` | `true` | no |
| <a name="input_allow_scheduling_on_control_planes"></a> [allow\_scheduling\_on\_control\_planes](#input\_allow\_scheduling\_on\_control\_planes) | Allow scheduling on control planes | `bool` | `false` | no |
| <a name="input_apply_mode"></a> [apply\_mode](#input\_apply\_mode) | How config changes are applied to existing nodes: `auto`, `reboot`, `no_reboot`, `staged` or `staged_if_needing_reboot`. The default stages a change that needs a reboot instead of rebooting the node, see the README | `string` | `"staged_if_needing_reboot"` | no |
| <a name="input_cluster_ip"></a> [cluster\_ip](#input\_cluster\_ip) | IPv6 LB IP to cluster | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Cluster Name | `string` | n/a | yes |
| <a name="input_cores"></a> [cores](#input\_cores) | Number of CPU Cores per node | `number` | `2` | no |
| <a name="input_cpu_type"></a> [cpu\_type](#input\_cpu\_type) | Proxmox CPU Type | `string` | `"Skylake-Server-noTSX-IBRS"` | no |
| <a name="input_datastore"></a> [datastore](#input\_datastore) | Proxmox Datastore | `string` | `"ceph1"` | no |
| <a name="input_description"></a> [description](#input\_description) | Proxmox VM description. Defaults to a text naming the cluster, the node type and that the VM is managed by OpenTofu | `string` | `null` | no |
| <a name="input_device_networkcard_name"></a> [device\_networkcard\_name](#input\_device\_networkcard\_name) | Netbox nic name | `string` | `"eth0"` | no |
| <a name="input_discovery_enabled"></a> [discovery\_enabled](#input\_discovery\_enabled) | Enable Talos Discovery | `bool` | `true` | no |
| <a name="input_discovery_service_endpoint"></a> [discovery\_service\_endpoint](#input\_discovery\_service\_endpoint) | Discovery Service Endpoint | `string` | `"https://discovery.talos.dev:443"` | no |
| <a name="input_disk"></a> [disk](#input\_disk) | Disk size (OS) per node (GB) | `number` | `24` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | DNS domain of the nodes: the search domain of the VMs, and the domain of each node's DNS name in Netbox (`<node_prefix><key>.<domain_name>`) | `string` | `"gathering.systems"` | no |
| <a name="input_extra_cert_sans"></a> [extra\_cert\_sans](#input\_extra\_cert\_sans) | More names and addresses for the certificates of the Kubernetes API and the Talos API, next to `localhost` and `cluster_ip`: the DNS name of the API load balancer, for example | `list(string)` | `[]` | no |
| <a name="input_gateway"></a> [gateway](#input\_gateway) | IPv6 default gateway of the nodes. Defaults to host 1 of `netbox_node_prefix` | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version | `string` | `"v1.35.5"` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory size per node (MB) | `number` | `4096` | no |
| <a name="input_nameservers"></a> [nameservers](#input\_nameservers) | DNS Servers. Use DNS64 if this is a IPv6 only cluster | `list(string)` | <pre>[<br/>  "2606:4700:4700::64"<br/>]</pre> | no |
| <a name="input_netbox_cluster_name"></a> [netbox\_cluster\_name](#input\_netbox\_cluster\_name) | Name of the Netbox cluster the VMs are registered in | `string` | `"pve"` | no |
| <a name="input_netbox_device_role_name"></a> [netbox\_device\_role\_name](#input\_netbox\_device\_role\_name) | Name of the Netbox device role of the VMs | `string` | `"Server"` | no |
| <a name="input_netbox_node_prefix"></a> [netbox\_node\_prefix](#input\_netbox\_node\_prefix) | Node IPv6 prefix in CIDR notation. Host 1 of it is the default `gateway`. Must be the prefix `netbox_node_prefix_id` refers to | `string` | n/a | yes |
| <a name="input_netbox_node_prefix_id"></a> [netbox\_node\_prefix\_id](#input\_netbox\_node\_prefix\_id) | Netbox ID of the node prefix. Node addresses are allocated from it. Required unless `netbox_node_prefix_lookup` is true | `number` | `null` | no |
| <a name="input_netbox_node_prefix_lookup"></a> [netbox\_node\_prefix\_lookup](#input\_netbox\_node\_prefix\_lookup) | Look up the Netbox ID of `netbox_node_prefix` instead of taking it from `netbox_node_prefix_id`. Only for a prefix that exists before the plan, see the README | `bool` | `false` | no |
| <a name="input_netbox_site_id"></a> [netbox\_site\_id](#input\_netbox\_site\_id) | Netbox ID of the site the VMs are registered in | `number` | n/a | yes |
| <a name="input_node_keys"></a> [node\_keys](#input\_node\_keys) | One key per node, known at plan time. Each node is named `<node_prefix><key>` and tracked by its key, so any node can be removed without touching the others. Only a worker pool may be empty | `list(string)` | n/a | yes |
| <a name="input_node_prefix"></a> [node\_prefix](#input\_node\_prefix) | Prefix for node name. The node's key is appended to form the hostname. Also part of the machine config snippet name, so it must differ between the pools of a cluster | `string` | n/a | yes |
| <a name="input_node_vlan_vid"></a> [node\_vlan\_vid](#input\_node\_vlan\_vid) | VLAN to place nodes | `number` | n/a | yes |
| <a name="input_oidc"></a> [oidc](#input\_oidc) | OIDC for kube-apiserver. Null leaves OIDC off. Tokens are accepted for `client_id` and for each of `audiences`. Set `groups_claim` to `""` to give the users no groups, and a prefix to `""` for no prefix. `groups_prefix` is also put in front of the group in the cluster-admin binding, which `cluster_admin_binding = false` leaves out | <pre>object({<br/>    issuer_url      = string<br/>    client_id       = string<br/>    audiences       = optional(list(string), [])<br/>    username_claim  = optional(string, "preferred_username")<br/>    username_prefix = optional(string, "oidc:")<br/>    groups_claim    = optional(string, "groups")<br/>    groups_prefix   = optional(string, "oidc:")<br/>    # The ClusterRoleBinding of the group <cluster_name>-cluster-admin<br/>    cluster_admin_binding = optional(bool, true)<br/>  })</pre> | `null` | no |
| <a name="input_on_boot"></a> [on\_boot](#input\_on\_boot) | Start the VMs when their Proxmox host boots | `bool` | `false` | no |
| <a name="input_on_destroy"></a> [on\_destroy](#input\_on\_destroy) | What happens to a node when it is removed from the pool. By default the VM is deleted without telling Talos. `{ reset = true }` resets the node first, which makes a control plane leave etcd; the node must be reachable for that. A change only takes effect once applied, see the README | <pre>object({<br/>    graceful = optional(bool, true)<br/>    reset    = optional(bool, false)<br/>    reboot   = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_pod_subnets"></a> [pod\_subnets](#input\_pod\_subnets) | k8s pod subnets in CIDR notation, at least one | `list(string)` | n/a | yes |
| <a name="input_proxmox_nodes"></a> [proxmox\_nodes](#input\_proxmox\_nodes) | Proxmox hosts to use, in placement order: the snippet is uploaded to each and node N of `node_keys` is created on host N, wrapping around. Defaults to every host the API returns, in API order | `list(string)` | `null` | no |
| <a name="input_proxmox_online_only"></a> [proxmox\_online\_only](#input\_proxmox\_online\_only) | Create new VMs on online hosts only. The snippet still goes to every host. Ignored when `proxmox_nodes` is set | `bool` | `false` | no |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | k8s service subnets in CIDR notation, at least one | `list(string)` | n/a | yes |
| <a name="input_snippet_datastore"></a> [snippet\_datastore](#input\_snippet\_datastore) | Proxmox datastore the machine config snippet is uploaded to on every host. Must allow the `snippets` content type | `string` | `"local"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Proxmox VM tags | `list(string)` | <pre>[<br/>  "kubernetes",<br/>  "terraform"<br/>]</pre> | no |
| <a name="input_talos_client_configuration"></a> [talos\_client\_configuration](#input\_talos\_client\_configuration) | Talos client configuration, the `client_configuration` attribute of a `talos_machine_secrets` resource | <pre>object({<br/>    ca_certificate     = string<br/>    client_certificate = string<br/>    client_key         = string<br/>  })</pre> | n/a | yes |
| <a name="input_talos_inline_manifests"></a> [talos\_inline\_manifests](#input\_talos\_inline\_manifests) | Talos Inline Manifests. Only applied through control planes | <pre>list(object({<br/>    name     = string<br/>    contents = string<br/>  }))</pre> | `[]` | no |
| <a name="input_talos_machine_secrets"></a> [talos\_machine\_secrets](#input\_talos\_machine\_secrets) | Talos machine secrets, the `machine_secrets` attribute of a `talos_machine_secrets` resource | <pre>object({<br/>    certs = object({<br/>      etcd               = object({ cert = string, key = string })<br/>      k8s                = object({ cert = string, key = string })<br/>      k8s_aggregator     = object({ cert = string, key = string })<br/>      k8s_serviceaccount = object({ key = string })<br/>      os                 = object({ cert = string, key = string })<br/>    })<br/>    cluster = object({ id = string, secret = string })<br/>    secrets = object({<br/>      bootstrap_token             = string<br/>      secretbox_encryption_secret = string<br/>      aescbc_encryption_secret    = optional(string)<br/>    })<br/>    trustdinfo = object({ token = string })<br/>  })</pre> | n/a | yes |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos version contract the machine config is generated for, v1.14 or later. It does not select the installed Talos image. The nodes must run at least this version | `string` | `"v1.14.2"` | no |
| <a name="input_template_node_name"></a> [template\_node\_name](#input\_template\_node\_name) | Proxmox host the template is on | `string` | `"pve1"` | no |
| <a name="input_template_vm_id"></a> [template\_vm\_id](#input\_template\_vm\_id) | VM ID of the Talos template to clone | `number` | `9201` | no |
| <a name="input_time_servers"></a> [time\_servers](#input\_time\_servers) | List of time\_servers | `list(string)` | <pre>[<br/>  "time.cloudflare.com"<br/>]</pre> | no |
| <a name="input_type"></a> [type](#input\_type) | worker or controlplane | `string` | n/a | yes |
| <a name="input_vm_bridge"></a> [vm\_bridge](#input\_vm\_bridge) | Proxmox Network Bridge | `string` | `"vmbr0"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster Name |
| <a name="output_config_patches"></a> [config\_patches](#output\_config\_patches) | Config patches of the pool, one per configuration document. For a worker the settings every node uses; for a control plane also the control-plane settings and the inline manifests |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig. Output only on type controlplane |
| <a name="output_machine_configuration"></a> [machine\_configuration](#output\_machine\_configuration) | Rendered machine config of the pool, as uploaded in the snippet. Holds the cluster secrets |
| <a name="output_nodes_by_key"></a> [nodes\_by\_key](#output\_nodes\_by\_key) | Nodes as a map from node key to an object with `name` and `ip`. The keys and names are known at plan time |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Talosctl config. Output only on type controlplane |
<!-- END_TF_DOCS -->
