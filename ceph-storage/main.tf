locals {
  # ceph-csi keeps its CephFS volumes in this subvolume group, which the provider cannot create
  subvolume_group = "csi"
}

## RBD
resource "ceph_osd_pool" "rbd" {
  name        = "${var.cluster_name}-rbd-pool"
  size        = var.size
  min_size    = var.min_size
  application = ["rbd"]

  # The PG autoscaler owns pg_num
  lifecycle {
    ignore_changes = [pg_num]

    # Checked here because a variable validation cannot refer to a second variable in OpenTofu 1.8
    precondition {
      condition     = var.min_size <= var.size
      error_message = "min_size must not be greater than size."
    }
  }
}

resource "ceph_auth" "rbd" {
  entity = "client.${var.cluster_name}-rbd"
  caps = {
    mon = "profile rbd"
    osd = "profile rbd pool=${ceph_osd_pool.rbd.name}"
  }
}

## CephFS
resource "ceph_osd_pool" "cephfs_metadata" {
  name        = "${var.cluster_name}-cephfs_metadata"
  type        = "replicated"
  size        = var.size
  min_size    = var.min_size
  application = ["cephfs"]

  lifecycle {
    ignore_changes = [pg_num]
  }
}

resource "ceph_osd_pool" "cephfs_data" {
  name        = "${var.cluster_name}-cephfs_data"
  type        = "replicated"
  size        = var.size
  min_size    = var.min_size
  application = ["cephfs"]

  lifecycle {
    ignore_changes = [pg_num]
  }
}

resource "ceph_fs" "this" {
  name          = "${var.cluster_name}-cephfs"
  metadata_pool = ceph_osd_pool.cephfs_metadata.name
  data_pools    = [ceph_osd_pool.cephfs_data.name]
}

# Read-write access to the volumes of ceph-csi, under /volumes/<subvolume group>
resource "ceph_auth" "cephfs" {
  entity = "client.${var.cluster_name}-cephfs"
  caps = {
    mon = "allow r fsname=${ceph_fs.this.name}"
    mgr = "allow rw"
    mds = "allow r fsname=${ceph_fs.this.name} path=/volumes, allow rws fsname=${ceph_fs.this.name} path=/volumes/${local.subvolume_group}"
    osd = "allow rw tag cephfs metadata=${ceph_fs.this.name}, allow rw tag cephfs data=${ceph_fs.this.name}"
  }
}
