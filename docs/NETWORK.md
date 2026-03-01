# Network Architecture

## 1. Topology Overview

We use a **Public Bridge** topology. Virtual machines are not hidden behind NAT; they sit directly on the physical LAN (`192.168.20.0/24`) alongside the bare metal hosts.

```text
Home Lab Network (192.168.20.0/24)
├── Router/Gateway (192.168.20.1)
├── DNS (1.1.1.1, 8.8.8.8)
│
├── bm-hypervisor-01 [Physical]
│   ├── Interface: enp0s25 (Slave to br0)
│   └── Interface: br0 (Static IP: 192.168.20.20)
│       │
│       ├── vm-k8s-node-01 (192.168.20.51)
│       ├── vm-k8s-node-02 (192.168.20.52)
│       └── vm-k8s-node-03 (192.168.20.53)
│
├── bm-hypervisor-02 [Physical]
│   ├── Interface: eno1 (Slave to br0)
│   └── Interface: br0 (Static IP: 192.168.20.33)
│       │
│       └── vm-dev-container-01 (192.168.20.61)
│
└── bm-hypervisor-03 [Physical]
    └── Interface: br0 (Static IP: 192.168.20.22)

```

## 2. IP Address Allocation (IPAM)

> **See also:** [`TOPOLOGY.md`](TOPOLOGY.md) for complete infrastructure topology and VM specifications.

| Role            | Hostname              | IP Address       | Notes                            |
| --------------- | --------------------- | ---------------- | -------------------------------- |
| **Gateway**     | Router                | `192.168.20.1`   | UniFi/ISP Router                 |
| **Hypervisors** | `bm-hypervisor-01`    | `192.168.20.20`  | Storage & K8s Control Plane Host |
|                 | `bm-hypervisor-02`    | `192.168.20.33`  | Dev Container Host               |
|                 | `bm-hypervisor-03`    | `192.168.20.22`  | GPU/ML Host                      |
|                 | `bm-hypervisor-04`    | `192.168.10.194` | _Legacy Network (Testing)_       |
| **K8s Nodes**   | `vm-k8s-node-01`      | `192.168.20.51`  | Control Plane                    |
|                 | `vm-k8s-node-02`      | `192.168.20.52`  | Worker                           |
|                 | `vm-k8s-node-03`      | `192.168.20.53`  | Worker                           |
| **Dev**         | `vm-dev-container-01` | `192.168.20.61`  | Remote Docker Host               |
| **Services**    | `vm-service-01`       | `192.168.20.71`  | Database/Misc                    |

## 3. Host Configuration (Netplan)

The physical hosts must configure a **Bridge (`br0`)** with a **Static IP**. This ensures the host is reachable at a known address even if DHCP fails, and provides the attachment point for VMs.

### `bm-hypervisor-01` Configuration

_Current Interface: `enp0s25_`

**Target File:** `/etc/netplan/01-network-config.yaml`

```yaml
network:
  version: 2
  ethernets:
    enp0s25:
      dhcp4: no
      dhcp6: no
    # Optional secondary interface (leave as DHCP or disable)
    enp5s0:
      dhcp4: true
      dhcp6: true
  bridges:
    br0:
      interfaces: [enp0s25]
      # Static IP Configuration
      addresses:
        - 192.168.20.20/24
      routes:
        - to: default
          via: 192.168.20.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      parameters:
        stp: false
        forward-delay: 0
      dhcp4: no
      dhcp6: no
```

> **Note:** Applying this change requires running `sudo netplan apply`. If connected via SSH on the old IP/DHCP address, the connection will drop.

## 4. Virtual Machine Configuration (Cloud-Init)

VMs will not use Netplan directly. Instead, Terraform injects a `network-config` snippet via Cloud-Init during provisioning.

**Terraform Template (`network_config.cfg`):**

```yaml
version: 2
ethernets:
  ens3:
    dhcp4: false
    addresses: [${ip_address}/24]
    gateway4: 192.168.20.1
    nameservers:
      addresses: [1.1.1.1, 8.8.8.8]

```

**Terraform Resource:**

```hcl
resource "libvirt_domain" "k8s_node" {
  name   = "vm-k8s-node-01"
  # ...
  network_interface {
    bridge = "br0"
    # Note: We do NOT set IP here. Libvirt just plugs the cable.
    # The IP is set inside the OS by Cloud-Init above.
  }
}

```
