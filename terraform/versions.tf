# versions.tf - Terraform and provider version constraints
terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8"
    }
  }
}

# Configure the libvirt provider to connect via SSH
provider "libvirt" {
  uri = var.libvirt_uri
}
