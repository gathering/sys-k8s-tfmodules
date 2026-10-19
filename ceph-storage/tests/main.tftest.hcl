# Pools, filesystem and clients, with the provider mocked.

mock_provider "ceph" {
  mock_resource "ceph_auth" {
    defaults = {
      key = "mock-key"
    }
  }
}

variables {
  cluster_name = "test"
}

# The names are those of the pools, filesystem and clients made before the module: a change
# replaces them, and their data
run "names" {
  command = apply

  assert {
    condition = alltrue([
      ceph_osd_pool.rbd.name == "test-rbd-pool",
      ceph_osd_pool.cephfs_metadata.name == "test-cephfs_metadata",
      ceph_osd_pool.cephfs_data.name == "test-cephfs_data",
      ceph_fs.this.name == "test-cephfs",
      ceph_auth.rbd.entity == "client.test-rbd",
      ceph_auth.cephfs.entity == "client.test-cephfs",
    ])
    error_message = "A name of a pool, the filesystem or a client changed."
  }

  assert {
    condition = alltrue([
      for pool in [ceph_osd_pool.rbd, ceph_osd_pool.cephfs_metadata, ceph_osd_pool.cephfs_data] : pool.size == 3 && pool.min_size == 2
    ])
    error_message = "Every pool must default to 3 replicas and serve I/O with 2."
  }

  assert {
    condition = alltrue([
      ceph_osd_pool.rbd.application == tolist(["rbd"]),
      ceph_osd_pool.cephfs_metadata.application == tolist(["cephfs"]),
      ceph_osd_pool.cephfs_data.application == tolist(["cephfs"]),
      ceph_fs.this.metadata_pool == "test-cephfs_metadata",
      ceph_fs.this.data_pools == toset(["test-cephfs_data"]),
    ])
    error_message = "The pools must be tagged for their application, and the filesystem built from the CephFS pools."
  }

  assert {
    condition = ceph_auth.rbd.caps == tomap({
      mon = "profile rbd"
      osd = "profile rbd pool=test-rbd-pool"
    })
    error_message = "The RBD client must reach its own pool only."
  }

  assert {
    condition = ceph_auth.cephfs.caps == tomap({
      mon = "allow r fsname=test-cephfs"
      mgr = "allow rw"
      mds = "allow r fsname=test-cephfs path=/volumes, allow rws fsname=test-cephfs path=/volumes/csi"
      osd = "allow rw tag cephfs metadata=test-cephfs, allow rw tag cephfs data=test-cephfs"
    })
    error_message = "The CephFS client must reach its own filesystem only, read-write under /volumes/csi."
  }

  assert {
    condition = alltrue([
      output.rbd.pool == "test-rbd-pool",
      output.rbd.user == "test-rbd",
      output.rbd.key == "mock-key",
      output.cephfs.fs_name == "test-cephfs",
      output.cephfs.subvolume_group == "csi",
      output.cephfs.user == "test-cephfs",
      output.cephfs.key == "mock-key",
    ])
    error_message = "An output no longer carries the value its name says."
  }
}

run "replicas" {
  command = plan

  variables {
    size     = 2
    min_size = 1
  }

  assert {
    condition = alltrue([
      for pool in [ceph_osd_pool.rbd, ceph_osd_pool.cephfs_metadata, ceph_osd_pool.cephfs_data] : pool.size == 2 && pool.min_size == 1
    ])
    error_message = "size and min_size must reach every pool."
  }
}

run "min_size_above_size" {
  command = plan

  variables {
    size     = 2
    min_size = 3
  }

  expect_failures = [
    ceph_osd_pool.rbd,
  ]
}

run "invalid_inputs" {
  command = plan

  variables {
    cluster_name = "not a name"
    size         = 0
    min_size     = 1.5
  }

  expect_failures = [
    var.cluster_name,
    var.size,
    var.min_size,
  ]
}
