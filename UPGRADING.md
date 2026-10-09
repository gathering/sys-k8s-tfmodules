# Upgrading

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
