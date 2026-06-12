module "vsphere_vm" {
  for_each = var.vms

  source = "../../modules/vsphere-vm"

  vm_name                    = coalesce(each.value.vm_name, each.key)
  instance_id                = each.key
  hostname                   = each.value.hostname
  datacenter                 = coalesce(each.value.datacenter, var.datacenter)
  cluster                    = each.value.cluster != null ? each.value.cluster : var.cluster
  host                       = each.value.host != null ? each.value.host : var.host
  datastore                  = coalesce(each.value.datastore, lookup(var.host_datastore_map, coalesce(each.value.host, var.host, ""), ""), var.datastore)
  network                    = coalesce(each.value.network, var.network)
  template_name              = coalesce(each.value.template_name, var.template_name)
  folder                     = each.value.folder != null ? each.value.folder : var.folder
  resource_pool_id           = each.value.resource_pool_id != null ? each.value.resource_pool_id : var.resource_pool_id
  num_cpus                   = coalesce(each.value.num_cpus, var.num_cpus)
  memory_mb                  = coalesce(each.value.memory_mb, var.memory_mb)
  cpu_hot_add_enabled        = coalesce(each.value.cpu_hot_add_enabled, var.cpu_hot_add_enabled)
  memory_hot_add_enabled     = coalesce(each.value.memory_hot_add_enabled, var.memory_hot_add_enabled)
  disk_size_gb               = coalesce(each.value.disk_size_gb, var.disk_size_gb)
  firmware                   = each.value.firmware != null ? each.value.firmware : var.firmware
  guest_id                   = each.value.guest_id != null ? each.value.guest_id : var.guest_id
  adapter_type               = each.value.adapter_type != null ? each.value.adapter_type : var.adapter_type
  thin_provisioned           = each.value.thin_provisioned != null ? each.value.thin_provisioned : var.thin_provisioned
  wait_for_guest_ip_timeout  = coalesce(each.value.wait_for_guest_ip_timeout, var.wait_for_guest_ip_timeout)
  wait_for_guest_net_timeout = coalesce(each.value.wait_for_guest_net_timeout, var.wait_for_guest_net_timeout)
  domain                     = each.value.domain != null ? each.value.domain : var.domain
  ipv4_address               = each.value.ipv4_address
  ipv4_prefix_length         = coalesce(each.value.ipv4_prefix_length, var.ipv4_prefix_length)
  ipv4_gateway               = coalesce(each.value.ipv4_gateway, var.ipv4_gateway)
  dns_servers                = coalesce(each.value.dns_servers, var.dns_servers)
  default_user               = coalesce(each.value.default_user, var.default_user)
  default_user_password      = each.value.default_user_password != null ? each.value.default_user_password : var.default_user_password
  ssh_authorized_keys        = coalesce(each.value.ssh_authorized_keys, var.ssh_authorized_keys)
  extra_cloud_init_userdata  = each.value.extra_cloud_init_userdata
  data_disks                 = each.value.data_disks
  extra_network_interfaces   = each.value.extra_network_interfaces
}

output "vms" {
  value = {
    for name, vm in module.vsphere_vm : name => {
      vm_id              = vm.vm_id
      vm_name            = vm.vm_name
      default_ip_address = vm.default_ip_address
    }
  }
}
