# variables.tf - Input variable definitions

# =============================================================================
# Provider Configuration
# =============================================================================

variable "libvirt_uri" {
  description = "Libvirt connection URI (e.g., qemu+ssh://user@host/system)"
  type        = string
  default     = "qemu+ssh://fastctl@192.168.20.20/system"
}

# =============================================================================
# Base Image Configuration
# =============================================================================

variable "base_image_url" {
  description = "URL to Ubuntu 24.04 cloud image"
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "storage_pool" {
  description = "Libvirt storage pool name for VM disks"
  type        = string
  default     = "default"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "bridge_name" {
  description = "Name of the network bridge on the hypervisor"
  type        = string
  default     = "br0"
}

variable "network_gateway" {
  description = "Default gateway IP address"
  type        = string
  default     = "192.168.20.1"
}

variable "network_dns" {
  description = "DNS server addresses"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

# =============================================================================
# VM User Configuration
# =============================================================================

variable "vm_user" {
  description = "Default user to create on VMs"
  type        = string
  default     = "fastctl"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

# =============================================================================
# VM Definitions
# =============================================================================

variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    vcpu       = number
    memory_mb  = number
    disk_gb    = number
    ip_address = string
    role       = string
    # Optional GPU passthrough configuration
    gpu_devices = optional(list(object({
      pci_slot        = string                     # GPU core (e.g., "0000:86:00.0")
      audio_pci_slot  = optional(string)           # Audio (e.g., "0000:86:00.1")
      extra_pci_slots = optional(list(string), []) # Additional devices (USB, Serial, etc.)
    })), [])
  }))
  default = {
    "vm-k8s-node-01" = {
      vcpu       = 4
      memory_mb  = 16384
      disk_gb    = 50
      ip_address = "192.168.20.51"
      role       = "k8s-control-plane"
    }
    "vm-k8s-node-02" = {
      vcpu       = 4
      memory_mb  = 16384
      disk_gb    = 50
      ip_address = "192.168.20.52"
      role       = "k8s-worker"
    }
    "vm-k8s-node-03" = {
      vcpu       = 4
      memory_mb  = 16384
      disk_gb    = 50
      ip_address = "192.168.20.53"
      role       = "k8s-worker"
    }
    "vm-dev-container-01" = {
      vcpu       = 8
      memory_mb  = 32768
      disk_gb    = 100
      ip_address = "192.168.20.61"
      role       = "dev-container"
    }
    "vm-service-01" = {
      vcpu       = 4
      memory_mb  = 16384
      disk_gb    = 20
      ip_address = "192.168.20.71"
      role       = "service"
    }
    # GPU VMs - uncomment when ready to deploy
    # "vm-gpu-01" = {
    #   vcpu       = 16
    #   memory_mb  = 49152  # 48GB (host has 64GB total)
    #   disk_gb    = 200
    #   ip_address = "192.168.20.81"
    #   role       = "gpu-ml"
    #   gpu_devices = [
    #     {
    #       pci_slot       = "0000:01:00.0"  # RTX 3090 GPU (bm-hypervisor-02)
    #       audio_pci_slot = "0000:01:00.1"  # RTX 3090 Audio
    #     }
    #   ]
    # }
    # "vm-gpu-02" = {
    #   vcpu       = 16
    #   memory_mb  = 49152  # 48GB (host has 64GB total)
    #   disk_gb    = 200
    #   ip_address = "192.168.20.82"
    #   role       = "gpu-ml"
    #   gpu_devices = [
    #     {
    #       pci_slot        = "0000:07:00.0"  # RX 7900 XTX #1 GPU (bm-hypervisor-03)
    #       audio_pci_slot  = "0000:07:00.1"  # RX 7900 XTX #1 Audio
    #       extra_pci_slots = []              # No extra devices for this GPU
    #     }
    #   ]
    # }
  }
}
