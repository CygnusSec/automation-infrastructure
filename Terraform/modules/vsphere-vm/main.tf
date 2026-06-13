data "vsphere_datacenter" "this" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "this" {
  count = local.use_cluster ? 1 : 0

  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_host" "this" {
  count = local.use_cluster ? 0 : 1

  name          = var.host
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_datastore" "this" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_network" "this" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_network" "extra" {
  count         = length(var.extra_network_interfaces)
  name          = var.extra_network_interfaces[count.index].network
  datacenter_id = data.vsphere_datacenter.this.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.this.id
}

locals {
  use_cluster = var.cluster == null ? false : trimspace(var.cluster) != ""
  use_dhcp    = var.ipv4_address == "" || lower(var.ipv4_address) == "dhcp"

  resolved_resource_pool_id = var.resource_pool_id != null ? var.resource_pool_id : (local.use_cluster ? data.vsphere_compute_cluster.this[0].resource_pool_id : data.vsphere_host.this[0].resource_pool_id)
  resolved_firmware         = var.firmware != "" ? var.firmware : data.vsphere_virtual_machine.template.firmware
  resolved_guest_id         = var.guest_id != "" ? var.guest_id : data.vsphere_virtual_machine.template.guest_id
  resolved_adapter_type     = var.adapter_type != "" ? var.adapter_type : try(data.vsphere_virtual_machine.template.network_interface_types[0], "vmxnet3")
  resolved_thin_provisioned = var.thin_provisioned != null ? var.thin_provisioned : try(data.vsphere_virtual_machine.template.disks[0].thin_provisioned, true)
  resolved_data_disks = [
    for index, disk in var.data_disks : merge(disk, {
      device = coalesce(disk.device, "/dev/sd${chr(98 + index)}")
    })
  ]

  metadata = templatefile("${path.module}/templates/metadata.yaml.tftpl", {
    instance_id        = coalesce(var.instance_id, var.vm_name)
    hostname           = var.hostname
    use_dhcp           = local.use_dhcp
    ipv4_address       = var.ipv4_address
    ipv4_prefix_length = var.ipv4_prefix_length
    ipv4_gateway       = var.ipv4_gateway
    dns_servers        = var.dns_servers
  })

  userdata = templatefile("${path.module}/templates/userdata.yaml.tftpl", {
    hostname                  = var.hostname
    default_user              = var.default_user
    default_user_password     = var.default_user_password
    ssh_authorized_keys       = var.ssh_authorized_keys
    extra_cloud_init_userdata = var.extra_cloud_init_userdata
    data_disks                = local.resolved_data_disks
  })
}

resource "vsphere_virtual_machine" "this" {
  name             = var.vm_name
  folder           = var.folder
  datastore_id     = data.vsphere_datastore.this.id
  resource_pool_id = local.resolved_resource_pool_id

  num_cpus = var.num_cpus
  memory   = var.memory_mb
  guest_id = local.resolved_guest_id
  firmware = local.resolved_firmware

  cpu_hot_add_enabled    = var.cpu_hot_add_enabled
  memory_hot_add_enabled = var.memory_hot_add_enabled

  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  wait_for_guest_ip_timeout  = var.wait_for_guest_ip_timeout
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout

  extra_config = {
    "guestinfo.metadata"          = base64encode(local.metadata)
    "guestinfo.metadata.encoding" = "base64"
    "guestinfo.userdata"          = base64encode(local.userdata)
    "guestinfo.userdata.encoding" = "base64"
  }

  network_interface {
    network_id   = data.vsphere_network.this.id
    adapter_type = local.resolved_adapter_type
  }

  dynamic "network_interface" {
    for_each = var.extra_network_interfaces
    content {
      network_id   = data.vsphere_network.extra[network_interface.key].id
      adapter_type = local.resolved_adapter_type
    }
  }

  disk {
    label            = "disk0"
    size             = var.disk_size_gb
    thin_provisioned = local.resolved_thin_provisioned
  }

  dynamic "disk" {
    for_each = var.data_disks
    content {
      label            = coalesce(disk.value.label, "disk${disk.key + 1}")
      size             = disk.value.size_gb
      thin_provisioned = disk.value.thin_provisioned
      unit_number      = disk.key + 1
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    dynamic "customize" {
      for_each = var.enable_customization ? [1] : []
      content {
        linux_options {
          host_name = var.hostname
          domain    = var.domain
        }

        # Primary network interface
        dynamic "network_interface" {
          for_each = local.use_dhcp ? [] : [1]
          content {
            ipv4_address = var.ipv4_address
            ipv4_netmask = var.ipv4_prefix_length
          }
        }

        dynamic "network_interface" {
          for_each = local.use_dhcp ? [1] : []
          content {}
        }

        # Extra network interfaces
        dynamic "network_interface" {
          for_each = var.extra_network_interfaces
          content {
            ipv4_address = network_interface.value.ipv4_address != "" ? network_interface.value.ipv4_address : null
            ipv4_netmask = network_interface.value.ipv4_address != "" ? network_interface.value.ipv4_netmask : null
          }
        }

        ipv4_gateway    = local.use_dhcp ? "" : var.ipv4_gateway
        dns_server_list = var.dns_servers
      }
    }
  }

  # --- SSH key provisioner (uncomment after the template enables SSH and password auth) ---
  # connection {
  #   type     = "ssh"
  #   host     = var.ipv4_address
  #   user     = var.default_user
  #   password = var.default_user_password
  #   timeout  = "5m"
  # }
  #
  # provisioner "remote-exec" {
  #   inline = [
  #     "mkdir -p ~/.ssh",
  #     "chmod 700 ~/.ssh",
  #     "echo '${join("\n", var.ssh_authorized_keys)}' >> ~/.ssh/authorized_keys",
  #     "chmod 600 ~/.ssh/authorized_keys",
  #   ]
  # }
}
