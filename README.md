# sys-k8s-tfmodules

OpenTofu modules used to deploy and manage Talos Kubernetes clusters at [The Gathering](https://gathering.org).

The modules cover the full infrastructure stack: VM provisioning on Proxmox, IP/VLAN allocation in Netbox, and network configuration on FortiGate — all IPv6-only.

## Modules

| Module | Description |
|---|---|
| [talos](./talos/) | Provisions Talos Kubernetes nodes on Proxmox, registers them in Netbox, and applies machine configuration |
| [fg-k8slb](./fg-k8slb/) | FortiGate IPv6 load balancer VIPs and firewall policy for Kubernetes and Talos APIs |
| [fg-bgp-neighbors](./fg-bgp-neighbors/) | FortiGate IPv6 BGP neighbors and prefix lists for a Kubernetes cluster |
| [fg-policy](./fg-policy/) | Generic FortiGate IPv6 firewall policy with optional NAT64 support |
| [fg-vlan](./fg-vlan/) | Provisions a VLAN end-to-end: allocates VLAN ID and IPv6 prefix in Netbox and creates the interface and address object on FortiGate |

## Prerequisites

| Tool | Purpose |
|---|---|
| [OpenTofu](https://opentofu.org) | Infrastructure provisioning |
| [terraform-docs](https://terraform-docs.io) | Documentation generation |
| Proxmox VE | Hypervisor for Kubernetes VMs |
| Netbox | IPAM and DCIM for IP/VLAN allocation |
| FortiGate | Firewall, BGP, and load balancing |

## Providers

| Provider | Source |
|---|---|
| FortiOS | `fortinetdev/fortios` |
| Netbox | `e-breuninger/netbox` |
| Proxmox | `bpg/proxmox` |
| Talos | `siderolabs/talos` |

## Updating documentation

Module READMEs are generated with [terraform-docs](https://terraform-docs.io). After changing variables or outputs in a module, regenerate its README:

```sh
terraform-docs markdown table --output-file README.md --output-mode inject <module-dir>
```

To regenerate all modules at once:

```sh
for dir in talos fg-k8slb fg-vlan fg-bgp-neighbors fg-policy; do
  terraform-docs markdown table --output-file README.md --output-mode inject "$dir"
done
```
