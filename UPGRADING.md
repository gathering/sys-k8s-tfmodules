# Upgrading

## To v0.1.0, from `main` before it

There is no in-place upgrade. v0.1.0 tracks nodes, BGP neighbors and realservers by a caller-chosen key instead of by position, names the machine config snippet per pool and has no `moved` blocks for resources of the modules before it. A plan of v0.1.0 against the state of an older deployment destroys and recreates its nodes.

Redeploy the cluster on v0.1.0 instead: [`examples/full-cluster`](./examples/full-cluster) is a complete root module, and [CHANGELOG.md](./CHANGELOG.md) lists what differs from the modules before it. The only earlier tag, `v0.0.1`, is older still and is not covered either.

A later release that requires editing module calls, or that moves or replaces resources, gets a section here.
