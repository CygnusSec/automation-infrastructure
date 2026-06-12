variable "vm_name" {
  type = string
}

variable "instance_id" {
  type    = string
  default = null
}

variable "hostname" {
  type = string
}

variable "datacenter" {
  type = string
}

variable "cluster" {
  type    = string
  default = null
}

variable "host" {
  type    = string
  default = null
}

variable "datastore" {
  type = string
}

variable "network" {
  type = string
}

variable "template_name" {
  type = string
}

variable "folder" {
  type    = string
  default = null
}

variable "resource_pool_id" {
  type    = string
  default = null
}

variable "num_cpus" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "cpu_hot_add_enabled" {
  type    = bool
  default = true
}

variable "memory_hot_add_enabled" {
  type    = bool
  default = true
}

variable "disk_size_gb" {
  type    = number
  default = 120
}

variable "firmware" {
  type    = string
  default = ""
}

variable "guest_id" {
  type    = string
  default = ""
}

variable "adapter_type" {
  type    = string
  default = ""
}

variable "thin_provisioned" {
  type    = bool
  default = null
}

variable "wait_for_guest_ip_timeout" {
  type    = number
  default = 10
}

variable "wait_for_guest_net_timeout" {
  type    = number
  default = 10
}

variable "domain" {
  type    = string
  default = "local"
}

variable "ipv4_address" {
  type    = string
  default = ""
}

variable "ipv4_prefix_length" {
  type    = number
  default = 24
}

variable "ipv4_gateway" {
  type    = string
  default = ""
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "default_user" {
  type    = string
  default = "ubuntu"
}

variable "default_user_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ssh_authorized_keys" {
  type    = list(string)
  default = []
}

variable "extra_cloud_init_userdata" {
  type    = string
  default = ""
}

variable "enable_customization" {
  description = "Enable vSphere guest customization (sets IP, hostname via VMware Tools without cloud-init)"
  type        = bool
  default     = true
}

variable "data_disks" {
  description = "Additional data disks to attach to the VM. Each disk specifies size, mount point, and optional thin provisioning."
  type = list(object({
    size_gb          = number
    mount_path       = string
    label            = optional(string)
    thin_provisioned = optional(bool, true)
  }))
  default = []
}

variable "extra_network_interfaces" {
  description = "Additional network interfaces beyond the primary. Each specifies network name and optional IP for customization."
  type = list(object({
    network      = string
    ipv4_address = optional(string, "")
    ipv4_netmask = optional(number, 24)
  }))
  default = []
}
