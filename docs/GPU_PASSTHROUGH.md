# GPU Passthrough for KVM VMs

This document describes how to configure GPU passthrough from hypervisors to KVM virtual machines for ML/AI workloads.

## Overview

GPU passthrough allows a physical GPU to be directly accessed by a virtual machine, providing near-native performance for compute workloads like:
- **Ollama** - Local LLM inference
- **ML Training** - PyTorch, TensorFlow workloads
- **CUDA/ROCm** - GPU-accelerated computing

## Hardware Summary

| Hypervisor | CPU | GPU | Passthrough Status |
|------------|-----|-----|-------------------|
| bm-hypervisor-01 | Intel Xeon | 1x NVIDIA GTX 960 (2GB) | Optional (limited VRAM) |
| bm-hypervisor-02 | AMD Ryzen | 1x NVIDIA RTX 3090 (24GB) | **Primary test target** |
| bm-hypervisor-03 | AMD EPYC | 6x AMD RX 7900 XTX (24GB each) | All GPUs for passthrough |
| bm-hypervisor-04 | Intel | None | N/A (down for repairs) |

## Prerequisites

### 1. BIOS Configuration

Before running Ansible, enable these settings in BIOS:

**Intel Systems (bm-hypervisor-01):**
- Enable **VT-d** (Intel Virtualization Technology for Directed I/O)
- Enable **Above 4G Decoding** (for large GPU BARs)

**AMD Systems (bm-hypervisor-02, bm-hypervisor-03):**
- Enable **AMD-Vi** / **IOMMU**
- Enable **Above 4G Decoding**
- Enable **SR-IOV** (if available)

### 2. Gather PCI Device Information

Run on each hypervisor to get actual PCI slot and device IDs:

```bash
# Find GPU PCI slots and device IDs
lspci -nn | grep -i vga
lspci -nn | grep -i nvidia
lspci -nn | grep -i amd

# Find associated audio devices
lspci -nn | grep -i audio

# Example output:
# 41:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3090] [10de:2204]
# 41:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef]
```

### 3. Update Host Variables

Edit the host_vars file for your hypervisor with the actual PCI information:

```yaml
# ansible/host_vars/bm-hypervisor-02.yml
gpu_passthrough:
  enabled: true
  cpu_vendor: amd  # or 'intel'

gpu_passthrough_devices:
  - name: "NVIDIA RTX 3090"
    pci_slot: "0000:41:00.0"       # From lspci output
    vendor_id: "10de"              # Vendor ID from [XXXX:YYYY]
    device_id: "2204"              # Device ID from [XXXX:YYYY]
    audio_pci_slot: "0000:41:00.1"
    audio_device_id: "1aef"
```

## Deployment

### Step 1: Run Ansible GPU Passthrough Role

```bash
# From control node (dt-dev-01)
cd ~/fun/homelab/ansible

# Test on bm-hypervisor-02 first
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-02
```

This configures:
- GRUB kernel parameters (`intel_iommu=on` or `amd_iommu=on`, `iommu=pt`)
- VFIO modules to load at boot
- VFIO-PCI device binding for GPUs
- GPU driver blacklisting (prevents host from using GPU)

### Step 2: Reboot the Hypervisor

```bash
# SSH to hypervisor and reboot
ssh bm-hypervisor-02
sudo reboot
```

### Step 3: Verify Configuration

After reboot, verify IOMMU and VFIO are working:

```bash
# Check IOMMU is enabled
dmesg | grep -i -E 'DMAR|IOMMU|AMD-Vi'

# Verify GPUs are bound to vfio-pci
lspci -nnk | grep -A2 VGA

# Expected output should show:
# Kernel driver in use: vfio-pci
```

### Step 4: Deploy GPU VM with Terraform

Update `terraform/variables.tf` to enable a GPU VM:

```hcl
"vm-gpu-01" = {
  vcpu       = 16
  memory_mb  = 65536  # 64GB
  disk_gb    = 200
  ip_address = "192.168.20.81"
  role       = "gpu-ml"
  gpu_devices = [
    {
      pci_slot       = "0000:41:00.0"
      audio_pci_slot = "0000:41:00.1"
    }
  ]
}
```

Then apply:

```bash
cd ~/fun/homelab/terraform
terraform plan
terraform apply
```

### Step 5: Verify GPU in VM

SSH to the new VM and verify GPU is visible:

```bash
ssh vm-gpu-01

# For NVIDIA GPUs
nvidia-smi

# For AMD GPUs
rocm-smi
```

## VM Specifications

| VM Type | vCPU | RAM | Disk | GPU |
|---------|------|-----|------|-----|
| vm-gpu (NVIDIA) | 16 | 48GB | 200GB | 1x RTX 3090 |
| vm-gpu (AMD) | 16 | 48GB | 200GB | 1-6x RX 7900 XTX |

> **Note:** Hypervisors have 64GB total RAM, so 48GB is allocated to VMs leaving headroom for the host OS.

## Troubleshooting

### IOMMU Not Enabled

```bash
# Check if IOMMU groups exist
find /sys/kernel/iommu_groups/ -type l

# If empty, IOMMU is not enabled - check BIOS settings
```

### GPU Still Using Host Driver

```bash
# Check current driver binding
lspci -nnk | grep -A3 VGA

# If not vfio-pci, check modprobe configs
cat /etc/modprobe.d/vfio-pci.conf
cat /etc/modprobe.d/blacklist-nvidia.conf

# Rebuild initramfs
sudo update-initramfs -u
sudo reboot
```

### IOMMU Groups Not Isolated

If multiple devices share an IOMMU group, all must be passed through together.

```bash
# Check IOMMU group membership
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n="${d##*/}"
  echo "IOMMU Group $(basename $(dirname $(dirname $d))): $(lspci -nns $n)"
done
```

### VM Fails to Start with GPU

```bash
# Check libvirt logs
sudo journalctl -u libvirtd -f

# Common issues:
# - PCI device not bound to vfio-pci
# - Incorrect PCI address format
# - IOMMU not enabled
```

## Rollback

To disable GPU passthrough and restore normal GPU usage on host:

```bash
# Remove VFIO configs
sudo rm /etc/modprobe.d/vfio*.conf
sudo rm /etc/modprobe.d/blacklist-nvidia.conf
sudo rm /etc/modprobe.d/blacklist-amd.conf
sudo rm /etc/modules-load.d/vfio.conf

# Remove IOMMU from GRUB (edit manually)
sudo vim /etc/default/grub
# Remove intel_iommu=on iommu=pt (or amd_iommu=on iommu=pt)

# Rebuild GRUB and initramfs
sudo update-grub
sudo update-initramfs -u
sudo reboot
```

## References

- [Arch Wiki: PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [VFIO Documentation](https://www.kernel.org/doc/html/latest/driver-api/vfio.html)
- [libvirt: Host device assignment](https://libvirt.org/formatdomain.html#host-device-assignment)
