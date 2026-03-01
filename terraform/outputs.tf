# outputs.tf - Output values for reference and integration

output "vm_ips" {
  description = "Map of VM names to their IP addresses"
  value = {
    for name, config in var.vms : name => config.ip_address
  }
}

output "vm_details" {
  description = "Detailed information about provisioned VMs"
  value = {
    for name, config in var.vms : name => {
      ip_address = config.ip_address
      vcpu       = config.vcpu
      memory_mb  = config.memory_mb
      disk_gb    = config.disk_gb
      role       = config.role
    }
  }
}

output "ssh_connection_strings" {
  description = "SSH connection strings for each VM"
  value = {
    for name, config in var.vms : name => "ssh ${var.vm_user}@${config.ip_address}"
  }
}

output "ansible_inventory_snippet" {
  description = "Ansible inventory snippet for the provisioned VMs"
  value       = <<-EOT
# Add to ansible/inventory.yaml under appropriate groups
%{for name, config in var.vms~}
${name}:
  ansible_host: ${config.ip_address}
%{endfor~}
EOT
}
