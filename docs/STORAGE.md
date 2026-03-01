# Storage Topology & Rules

> **See also:** [`TOPOLOGY.md`](TOPOLOGY.md) for hypervisor specifications and infrastructure details.

## 1. ZFS Configuration (bm-hypervisor-01)

| Pool Name   | Layout | Physical Devices                                           | Mountpoint           | NFS Export? |
| ----------- | ------ | ---------------------------------------------------------- | -------------------- | ----------- |
| `ssdpool`   | RAIDZ1 | `/dev/sdc`, `/dev/sdd`, `/dev/sde`, `/dev/sdf`, `/dev/sdg` | `/ssdpool/data`      | Yes         |
| `hddmirror` | Mirror | `/dev/sda`, `/dev/sdh`                                     | `/hddmirror/backups` | Yes         |
| `hddsingle` | Single | `/dev/sdb`                                                 | `/hddsingle/scratch` | Yes         |
| `nvmedata`  | Single | `/dev/nvme1n1`                                             | `/nvmedata`          | No          |

_Note: `/dev/nvme0n1` is reserved for OS (Root)._

## 2. NVMe Configuration (bm-hypervisor-02)

| Device         | Filesystem | Mountpoint | Purpose       |
| -------------- | ---------- | ---------- | ------------- |
| `/dev/nvme0n1` | ext4       | `/data`    | Local Storage |
| `/dev/nvme1n1` | ext4       | `/`        | OS (Root)     |

## 3. NVMe RAID Configuration (bm-hypervisor-03)

_Hardware: ASUS Hyper M.2 Card with 4x NVMe + 2x Onboard NVMe._

| Pool Name     | Layout | Devices                                      | Mountpoint | Purpose     |
| ------------- | ------ | -------------------------------------------- | ---------- | ----------- |
| `fastscratch` | Stripe | 5x NVMe (Identify specific device IDs later) | `/scratch` | ML Datasets |
| `os_disk`     | ext4   | 1x NVMe                                      | `/`        | OS (Root)   |

## 4. NFS Architecture

**Server:** `bm-hypervisor-01` (192.168.20.20)

**Exports:**

- `/ssdpool/data` (Network: 192.168.20.0/24, Options: `rw,sync,no_subtree_check`)
- `/hddmirror/backups` (Network: 192.168.20.0/24, Options: `rw,sync,no_subtree_check`)
- `/hddsingle/scratch` (Network: 192.168.20.0/24, Options: `rw,sync,no_subtree_check`)

**Clients:**

- `bm-hypervisor-02`
- `bm-hypervisor-03`
- All `vm-*` machines (optional, per role)

**Client Mount Strategy:**

- Use `fstab` via Ansible `mount` module.
- Mount target: `/mnt/[pool_name]`
