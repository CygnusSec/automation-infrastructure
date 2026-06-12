output "vm_id" {
  value = vsphere_virtual_machine.this.id
}

output "vm_name" {
  value = vsphere_virtual_machine.this.name
}

output "default_ip_address" {
  value = vsphere_virtual_machine.this.default_ip_address
}
