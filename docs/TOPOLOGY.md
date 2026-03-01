# Infrastructure Topology

## Physical Hosts (Hypervisors)

| Hostname         | IP Address     | CPU (Cores) | RAM  | GPU Capability     | Status    |
| ---------------- | -------------- | ----------- | ---- | ------------------ | --------- |
| bm-hypervisor-01 | 192.168.20.20  | 22 (Xeon)   | 128G | NVIDIA GTX 960 (2GB) | Available |
| bm-hypervisor-02 | 192.168.20.33  | 16 (Ryzen)  | 64G  | NVIDIA RTX 3090 (24GB) | Available |
| bm-hypervisor-03 | 192.168.20.22  | 32 (Epyc)   | 64G  | 6x AMD RX 7900 XTX (24GB each) | Available |
| bm-hypervisor-04 | 192.168.10.194 | 4 (Intel)   | 4G   | None (Testing)     | Repairs |

## Virtual Machine Specs (Templates)

| Role             | vCPU | RAM | Disk | Base Image   |
| ---------------- | ---- | --- | ---- | ------------ |
| vm-k8s-node      | 4    | 16G | 50G  | Ubuntu 24.04 |
| vm-service       | 4    | 16G | 20G  | Ubuntu 24.04 |
| vm-dev-container | 8    | 32G | 100G | Ubuntu 24.04 |
| vm-gpu           | 16   | 48G | 200G | Ubuntu 24.04 |

## Target State (What to Build)

| VM Hostname         | IP Address    | Hosting Hypervisor | Role          |
| ------------------- | ------------- | ------------------ | ------------- |
| vm-k8s-node-01      | 192.168.20.51 | bm-hypervisor-01   | Control Plane |
| vm-k8s-node-02      | 192.168.20.52 | bm-hypervisor-01   | Worker        |
| vm-k8s-node-03      | 192.168.20.53 | bm-hypervisor-01   | Worker        |
| vm-dev-container-01 | 192.168.20.61 | bm-hypervisor-01   | Dev Host      |
| vm-service-01       | 192.168.20.71 | bm-hypervisor-01   | Service       |
| vm-gpu-01           | 192.168.20.81 | bm-hypervisor-02   | GPU ML (RTX 3090) |
| vm-gpu-02           | 192.168.20.82 | bm-hypervisor-03   | GPU ML (RX 7900 XTX) |

## Desktops

| Hostname  | IP Address     | CPU (Cores) | RAM | Model                 | GPU Capability                                               | OS                  | Status    | Role                          |
| --------- | -------------- | ----------- | --- | --------------------- | ------------------------------------------------------------ | ------------------- | --------- | ----------------------------- |
| dt-dev-01 | 192.168.10.189 | 16 Ryzen7   | 96G | -                     | ThinkPad P14s Gen 5 AMD + ThinkPad Universal USB Type-C Dock | Ununtu Server 24.04 | Available | Ansible Control Node          |
| dt-dev-02 | 192.168.10.135 | 8 Indel     | 32G | NVIDIA GTX 1050Ti 4GB | Dell XPS 15 (9570) + Dell Thunderbolt Dock WD19TBS           | Ununtu Server 24.04 | Available | Ansible Control Node (backup) |
| dt-dev-03 | 192.168.10.136 | 8 Intel     | 16G | -                     |                                                              | MacOS               | Repairs   | Old Mac                       |
| dt-dev-04 | 192.168.10.137 | 8 Intel     | 16G | -                     |                                                              | MacOS               | Repairs   | Old Mac                       |
| dt-dev-05 | 192.168.10.138 | 12 M4       | 32G | -                     |                                                              | MacOS               | Repairs   | Office Mac                    |
