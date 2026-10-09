# Upgrading

## To v0.1.0, from `main` before it

There is no in-place upgrade. v0.1.0 tracks nodes, BGP neighbors and realservers by a caller-chosen key instead of by position, names the machine config snippet per pool and has no `moved` blocks for resources of the modules before it. A plan of v0.1.0 against the state of an older deployment destroys and recreates its nodes.

Redeploy the cluster on v0.1.0 instead: [`examples/full-cluster`](./examples/full-cluster) is a complete root module, and [CHANGELOG.md](./CHANGELOG.md) lists what differs from the modules before it. The only earlier tag, `v0.0.1`, is older still and is not covered either.

## To v0.3.0

v0.3.0 builds the machine config from the configuration documents of Talos 1.14. Not tried on a running cluster: do one cluster first, and a cluster you can lose before one you cannot.

1. Upgrade every node to Talos 1.14 or later (`talosctl upgrade`), and the Proxmox template with them.
2. Set `talos_version` to `v1.14.2` or leave it out, on every pool of the cluster. A value before v1.14 is rejected.
3. Plan. Every node shows its snippet file replaced and its config re-applied.
4. Before applying, compare the new config with what a node runs. The new config is the `machine_configuration` output of the pool:

   ```sh
   talosctl -n <node> apply-config --dry-run -f <new config>
   ```

   Apart from the settings moving into documents, expect the additions the changelog lists: secure mount options on EPHEMERAL, the filesystem trim and workload isolation.
5. Apply, control planes first. Talos applies what it can live; kube-apiserver restarts on every control plane, at the same time unless you apply with `-parallelism=1`.
6. Reboot the nodes one at a time for the rest to take effect, control planes first, and wait for each to be healthy.

Coming from v0.2.0 with `oidc` set: kube-apiserver moves from the file under `/var/lib/apiserver` to the one Talos writes. The old file stays on the node and is not used.

A later release that requires editing module calls, or that moves or replaces resources, gets a section here.
