output "rbd" {
  description = "What ceph-csi-rbd needs: the `pool`, and the cephx `user` (without `client.`) and `key`"
  sensitive   = true
  value = {
    pool = ceph_osd_pool.rbd.name
    user = trimprefix(ceph_auth.rbd.entity, "client.")
    key  = ceph_auth.rbd.key
  }
}

output "cephfs" {
  description = "What ceph-csi-cephfs needs: the filesystem `fs_name`, the `subvolume_group` its volumes go in, and the cephx `user` (without `client.`) and `key`"
  sensitive   = true
  value = {
    fs_name         = ceph_fs.this.name
    subvolume_group = local.subvolume_group
    user            = trimprefix(ceph_auth.cephfs.entity, "client.")
    key             = ceph_auth.cephfs.key
  }
}
