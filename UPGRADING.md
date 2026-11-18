# Upgrading

## To the next version: VM hardware

Every Talos VM gets a balloon device (`floating` equal to `dedicated`), a standard display, a serial port, and `discard` and SSD emulation on its disk. All of them need a restart of the VM, and the provider restarts each VM it changes: a plain apply restarts every node of a pool at once, which takes etcd below quorum on the control planes.

To choose when each node restarts, make the change in Proxmox first, one node at a time, and apply afterwards. The apply then has nothing to change on the VMs.

1. Check that etcd is healthy and has all members: `talosctl -n <node> etcd status`. Drain a worker first: `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`.
2. On a Proxmox host, set the same values the module sets, then restart the VM through Proxmox. A reboot from inside the guest (`talosctl reboot`) keeps the QEMU process and does not apply the change.

   ```sh
   qm config <vmid> | grep ^scsi0   # the disk's options now
   qm set <vmid> --memory <memory> --balloon <memory> --vga std --serial0 socket
   qm set <vmid> --scsi0 <the scsi0 line, with discard=on,ssd=1>
   qm reboot <vmid>     # applies pending changes
   qm pending <vmid>    # nothing pending afterwards
   ```

   `--scsi0` replaces every option of the disk: copy the line from `qm config` and change only `discard` and `ssd`.

3. Wait for the node to be `Ready` and etcd to list it again, `kubectl uncordon` a worker, then do the next node.
4. Plan: the VMs show no change. Apply.

Or apply with `-target` on one VM at a time: `-target='module.<pool>.proxmox_virtual_environment_vm.this["<key>"]'`.

## To v0.8.0

v0.8.0 turns kube-proxy off on a cluster that runs it since v0.3.0. Talos stops applying its manifest, but never deletes what it applied. Do one cluster at a time.

1. Apply v0.8.0. A cluster with `apply_mode = "staged"` only gets it at the next reboot of each control plane; take `staged` out first if its nodes have rebooted since the move to v0.3.0. On each control plane, `talosctl -n <node> get manifests | grep -i proxy` then prints nothing.
2. Save what Talos made for kube-proxy, then delete it: the DaemonSet and ServiceAccount `kube-system/kube-proxy`, and the ClusterRoleBinding `kube-proxy`. There is no ConfigMap.

   ```bash
   kubectl -n kube-system get ds/kube-proxy sa/kube-proxy clusterrolebinding/kube-proxy -o yaml > kube-proxy.yaml   # the rollback
   kubectl -n kube-system delete ds/kube-proxy sa/kube-proxy clusterrolebinding/kube-proxy
   ```

3. Check that the CNI serves every Service: with Cilium, `cilium-dbg status --verbose` shows the same KubeProxyReplacement details as before, and ClusterIP, NodePort and LoadBalancer Services and DNS answer.

kube-proxy's nftables rules stay on each node until its next reboot. A CNI that replaces kube-proxy, such as Cilium, translates Services before they are reached.

**Applying v0.7.0 again does not bring kube-proxy back**: Talos creates each bootstrap object only once, and keeps a list of them in the ConfigMap `kube-system/talos-bootstrap-manifests-inventory`. To roll back, apply the saved objects without what the server set: `grep -v -E '^ +(resourceVersion|uid|creationTimestamp):' kube-proxy.yaml | kubectl apply -f -`.

## To v0.1.0, from `main` before it

There is no in-place upgrade. v0.1.0 tracks nodes, BGP neighbors and realservers by a caller-chosen key instead of by position, names the machine config snippet per pool and has no `moved` blocks for resources of the modules before it. A plan of v0.1.0 against the state of an older deployment destroys and recreates its nodes.

Redeploy the cluster on v0.1.0 instead: [`examples/full-cluster`](./examples/full-cluster) is a complete root module, and [CHANGELOG.md](./CHANGELOG.md) lists what differs from the modules before it. The only earlier tag, `v0.0.1`, is older still and is not covered either.

## To v0.3.0

v0.3.0 builds the machine config from the configuration documents of Talos 1.14. Not tried on a running cluster: do one cluster first, and a cluster you can lose before one you cannot.

Move a running cluster with `apply_mode = "staged"`. Applied live, a node would run a mix until its next reboot: the new Kubernetes settings at once, while workload isolation and the mount options of EPHEMERAL only take effect at boot. Staged, nothing changes on a node until it is rebooted, and then all of it does.

1. Upgrade every node to Talos 1.14 or later (`talosctl upgrade`), and the Proxmox template with them.
2. On every pool of the cluster, set `apply_mode = "staged"`, and set `talos_version` to `v1.14.2` or leave it out. A value before v1.14 is rejected.
3. Plan. Every node shows its snippet file replaced and its config re-applied.
4. Before applying, compare the new config with what a node runs. The new config is the `machine_configuration` output of the pool:

   ```sh
   talosctl -n <node> apply-config --dry-run -f <new config>
   ```

   Apart from the settings moving into documents, expect what the changelog lists under "Changed".
5. Apply. Nothing changes on the nodes yet.
6. Reboot the nodes one at a time, control planes first, and wait for each to be healthy before the next. Check the first control plane well: that kube-apiserver answers, that an OIDC login works if `oidc` is set, and that pods with volumes start.
7. Take `apply_mode = "staged"` out again and apply. Later changes, to `oidc` among them, then apply live.

Talos does not check the content of the OIDC settings: kube-apiserver does, when it starts. With a wrong value it does not start, on the control plane that was rebooted. Correct `oidc`, apply and reboot that control plane again; the control planes that were not rebooted yet still answer.

Secrets stay readable: the key they are encrypted with is the same. A Secret stored unencrypted would not be: the config Talos generates for 1.14 no longer reads those. A cluster created by this module has none, because Talos encrypts Secrets from the first boot.

Coming from v0.2.0 with `oidc` set: kube-apiserver moves from the file under `/var/lib/apiserver` to the one Talos writes. The old file stays on the node and is not used.

A later release that requires editing module calls, or that moves or replaces resources, gets a section here.
