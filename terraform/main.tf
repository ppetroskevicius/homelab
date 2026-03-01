# main.tf - Core infrastructure resources (libvirt provider v0.9+)

# =============================================================================
# Base Image Volume
# Downloads Ubuntu 24.04 cloud image once and uses it as a backing store
# =============================================================================

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-24.04-base.qcow2"
  pool = var.storage_pool

  create = {
    content = {
      url = var.base_image_url
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

# =============================================================================
# Cloud-Init Configuration
# Generates ISO with user-data, meta-data, and network-config
# =============================================================================

resource "libvirt_cloudinit_disk" "vm_cloudinit" {
  for_each = var.vms

  name = "${each.key}-cloudinit"

  meta_data = yamlencode({
    instance-id    = each.key
    local-hostname = each.key
  })

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml", {
    hostname       = each.key
    username       = var.vm_user
    ssh_public_key = var.ssh_public_key
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yaml", {
    ip_address = each.value.ip_address
    gateway    = var.network_gateway
    dns        = var.network_dns
  })
}

# Upload cloud-init ISO to libvirt storage pool
resource "libvirt_volume" "vm_cloudinit" {
  for_each = var.vms

  name = "${each.key}-cloudinit.iso"
  pool = var.storage_pool

  create = {
    content = {
      url = libvirt_cloudinit_disk.vm_cloudinit[each.key].path
    }
  }
}

# =============================================================================
# VM Disk Volumes
# Each VM gets a disk using the base image as a backing store
# =============================================================================

resource "libvirt_volume" "vm_disk" {
  for_each = var.vms

  name = "${each.key}-disk.qcow2"
  pool = var.storage_pool
  # Capacity in bytes (provider has a bug with GiB unit reporting)
  capacity = each.value.disk_gb * 1024 * 1024 * 1024

  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }

  target = {
    format = {
      type = "qcow2"
    }
  }
}

# =============================================================================
# Virtual Machines
# =============================================================================

resource "libvirt_domain" "vm" {
  for_each = var.vms

  name        = each.key
  type        = "kvm"
  memory      = each.value.memory_mb
  memory_unit = "MiB"
  vcpu        = each.value.vcpu

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      { dev = "hd" },
      { dev = "cdrom" }
    ]
  }

  devices = {
    # Main disk
    disks = [
      {
        device = "disk"
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          file = {
            file = libvirt_volume.vm_disk[each.key].path
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      # Cloud-init disk
      {
        device    = "cdrom"
        read_only = true
        driver = {
          name = "qemu"
          type = "raw"
        }
        source = {
          file = {
            file = libvirt_volume.vm_cloudinit[each.key].path
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
      }
    ]

    # Network interface - bridged to br0
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          bridge = {
            bridge = var.bridge_name
          }
        }
      }
    ]

    # Serial console
    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
          port = 0
        }
      }
    ]

    # VNC graphics
    graphics = [
      {
        type           = "vnc"
        listen_type    = "address"
        listen_address = "127.0.0.1"
        autoport       = true
      }
    ]

    # QEMU guest agent channel
    channels = [
      {
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      }
    ]

    # ==========================================================================
    # GPU PCI Passthrough (optional)
    # ==========================================================================
    # Passes through GPU and audio devices to the VM
    # Requires IOMMU enabled on host and devices bound to vfio-pci
    # ==========================================================================
    hostdevs = concat(
      # GPU devices
      [for gpu in coalesce(each.value.gpu_devices, []) : {
        mode    = "subsystem"
        type    = "pci"
        managed = true
        source = {
          address = {
            domain   = tonumber("0x${split(":", gpu.pci_slot)[0]}")
            bus      = tonumber("0x${split(":", split(".", gpu.pci_slot)[0])[1]}")
            slot     = tonumber("0x${split(".", split(":", gpu.pci_slot)[1])[0]}")
            function = tonumber("0x${split(".", gpu.pci_slot)[1]}")
          }
        }
      }],
      # Audio devices (if specified)
      [for gpu in coalesce(each.value.gpu_devices, []) : {
        mode    = "subsystem"
        type    = "pci"
        managed = true
        source = {
          address = {
            domain   = tonumber("0x${split(":", gpu.audio_pci_slot)[0]}")
            bus      = tonumber("0x${split(":", split(".", gpu.audio_pci_slot)[0])[1]}")
            slot     = tonumber("0x${split(".", split(":", gpu.audio_pci_slot)[1])[0]}")
            function = tonumber("0x${split(".", gpu.audio_pci_slot)[1]}")
          }
        }
      } if gpu.audio_pci_slot != null],
      # Extra PCI devices (USB, Serial, etc. for multi-function GPUs)
      flatten([for gpu in coalesce(each.value.gpu_devices, []) : [
        for extra_slot in coalesce(gpu.extra_pci_slots, []) : {
          mode    = "subsystem"
          type    = "pci"
          managed = true
          source = {
            address = {
              domain   = tonumber("0x${split(":", extra_slot)[0]}")
              bus      = tonumber("0x${split(":", split(".", extra_slot)[0])[1]}")
              slot     = tonumber("0x${split(".", split(":", extra_slot)[1])[0]}")
              function = tonumber("0x${split(".", extra_slot)[1]}")
            }
          }
        }
      ]])
    )
  }

  # Start VM on creation
  running = true

  lifecycle {
    ignore_changes = [
      running,
    ]
  }
}
