# Ceph Storage

The storage of one Kubernetes cluster on an existing Ceph cluster, for ceph-csi: an RBD pool with a cephx client for ceph-csi-rbd, and a CephFS filesystem with its two pools and a cephx client for ceph-csi-cephfs. Call the module once per Kubernetes cluster.

| Object | Name |
|---|---|
| RBD pool | `<cluster_name>-rbd-pool` |
| RBD client | `client.<cluster_name>-rbd`, `profile rbd` on its pool only |
| CephFS metadata and data pools | `<cluster_name>-cephfs_metadata`, `<cluster_name>-cephfs_data` |
| CephFS filesystem | `<cluster_name>-cephfs` |
| CephFS client | `client.<cluster_name>-cephfs`, read-write under `/volumes/csi` of its filesystem only |

Every pool is replicated, 3 replicas by default, and serves I/O down to 2 (`size`, `min_size`). The PG autoscaler owns `pg_num`: the module never sets or changes it.

Changing `cluster_name` replaces every pool and the filesystem, with their data.

## The subvolume group

ceph-csi-cephfs keeps its volumes in the subvolume group `csi`, which the provider cannot create. Create it by hand once, after the first apply, or provisioning fails with `subvolume group 'csi' does not exist`:

```sh
ceph fs subvolumegroup create <cluster_name>-cephfs csi
```

## Example

```hcl
# Monitors and credentials come from the provider's environment variables: CEPH_MON_HOST,
# CEPH_ENTITY and CEPH_KEY
provider "ceph" {}

module "storage" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//ceph-storage?ref=v0.7.0"

  cluster_name = "my-cluster"
}

output "rbd" {
  sensitive = true
  value     = module.storage.rbd
}
```

The `rbd` and `cephfs` outputs are what the ceph-csi charts need, keys included:

```sh
tofu output -json rbd | jq -r .key
```

## Prerequisites

- The provider loads `librados.so.2` and `librbd.so.1`, and is built for `linux_amd64` only: OpenTofu runs it on Linux with the Ceph client libraries installed (`apt-get install librados2 librbd1`). On macOS it cannot be loaded, so `tofu validate` and `tofu test` of this module run in CI, not in pre-commit.
- A cephx entity for OpenTofu that may create pools, filesystems and clients, such as `client.admin`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_ceph"></a> [ceph](#requirement\_ceph) | 0.2.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_ceph"></a> [ceph](#provider\_ceph) | 0.2.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [ceph_auth.cephfs](https://registry.terraform.io/providers/gathering/ceph/0.2.0/docs/resources/auth) | resource |
| [ceph_auth.rbd](https://registry.terraform.io/providers/gathering/ceph/0.2.0/docs/resources/auth) | resource |
| [ceph_fs.this](https://registry.terraform.io/providers/gathering/ceph/0.2.0/docs/resources/fs) | resource |
| [ceph_osd_pool.cephfs_data](https://registry.terraform.io/providers/gathering/ceph/0.2.0/docs/resources/osd_pool) | resource |
| [ceph_osd_pool.cephfs_metadata](https://registry.terraform.io/providers/gathering/ceph/0.2.0/docs/resources/osd_pool) | resource |
| [ceph_osd_pool.rbd](https://registry.terraform.io/providers/gathering/ceph/0.2.0/docs/resources/osd_pool) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Kubernetes cluster the storage is for. Prefix of every pool, the filesystem and the cephx clients. Changing it replaces them all, with their data | `string` | n/a | yes |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Fewest replicas a pool still serves I/O with. At most `size` | `number` | `2` | no |
| <a name="input_size"></a> [size](#input\_size) | Number of replicas of every pool | `number` | `3` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cephfs"></a> [cephfs](#output\_cephfs) | What ceph-csi-cephfs needs: the filesystem `fs_name`, the `subvolume_group` its volumes go in, and the cephx `user` (without `client.`) and `key` |
| <a name="output_rbd"></a> [rbd](#output\_rbd) | What ceph-csi-rbd needs: the `pool`, and the cephx `user` (without `client.`) and `key` |
<!-- END_TF_DOCS -->
