variable "vsphere_server" {
  description = "vCenter FQDN/IP"
  type        = string
}

variable "vsphere_user" {
  description = "vCenter account"
  type        = string
}

variable "vsphere_password" {
  description = "vCenter password"
  type        = string
  sensitive   = true
}

variable "allow_unverified_ssl" {
  description = "Skip vCenter TLS certificate verification"
  type        = bool
  default     = true
}

variable "datacenter" {
  description = "Default datacenter name"
  type        = string
}

variable "cluster" {
  description = "Default cluster name. If the ESXi host is directly under the datacenter, set this to null and use host."
  type        = string
  default     = null
}

variable "host" {
  description = "Default ESXi host name when vCenter does not use a cluster"
  type        = string
  default     = null
}

variable "datastore" {
  description = "Default datastore name"
  type        = string
}

variable "host_datastore_map" {
  description = "Host-to-datastore mapping. When a VM specifies a host, automatically use the matching datastore."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = "Default port group or network name"
  type        = string
}

variable "template_name" {
  description = "Default template name to clone"
  type        = string
}

variable "folder" {
  description = "Default inventory folder for VMs. Use null for the root folder."
  type        = string
  default     = null
}

variable "resource_pool_id" {
  description = "Default resource pool ID. Use null for the cluster root resource pool."
  type        = string
  default     = null
}

variable "num_cpus" {
  description = "Default CPU count"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "Default RAM in MB"
  type        = number
  default     = 2048
}

variable "cpu_hot_add_enabled" {
  description = "Enable CPU hot add by default for VMs"
  type        = bool
  default     = true
}

variable "memory_hot_add_enabled" {
  description = "Enable memory hot add by default for VMs"
  type        = bool
  default     = true
}

variable "disk_size_gb" {
  description = "Default disk size in GB. Must not be smaller than the template disk."
  type        = number
  default     = 50
}

variable "firmware" {
  description = "Default firmware. Leave empty to inherit from the template. Common values: bios, efi."
  type        = string
  default     = ""
}

variable "guest_id" {
  description = "Guest OS ID override. Leave empty to inherit from the template."
  type        = string
  default     = ""
}

variable "adapter_type" {
  description = "Network adapter override. Leave empty to inherit from the template."
  type        = string
  default     = ""
}

variable "thin_provisioned" {
  description = "Thin provision disk"
  type        = bool
  default     = true
}

variable "wait_for_guest_ip_timeout" {
  description = "Provider timeout, in minutes, while waiting for VMware Tools to report an IP. Use 0 to skip waiting."
  type        = number
  default     = 10
}

variable "wait_for_guest_net_timeout" {
  description = "Provider timeout, in minutes, while waiting for routable guest networking. Use 0 to skip waiting."
  type        = number
  default     = 10
}

variable "domain" {
  description = "Default guest domain"
  type        = string
  default     = "local"
}

variable "ipv4_prefix_length" {
  description = "Default IPv4 prefix length"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "Default IPv4 gateway"
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "Default DNS servers"
  type        = list(string)
  default     = []
}

variable "default_user" {
  description = "Default guest user that receives SSH keys through cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "default_user_password" {
  description = "Plain-text password for default_user through cloud-init. Leave empty to avoid setting a password."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "Default SSH public keys injected through cloud-init guestinfo"
  type        = list(string)
  default     = []
}

variable "vms" {
  description = "VMs to manage. The map key is the stable Terraform state identity; use vm_name when the vCenter VM name must differ from the key."
  type = map(object({
    vm_name                    = optional(string)
    hostname                   = string
    ipv4_address               = optional(string, "")
    datacenter                 = optional(string)
    cluster                    = optional(string)
    host                       = optional(string)
    datastore                  = optional(string)
    network                    = optional(string)
    template_name              = optional(string)
    folder                     = optional(string)
    resource_pool_id           = optional(string)
    num_cpus                   = optional(number)
    memory_mb                  = optional(number)
    cpu_hot_add_enabled        = optional(bool)
    memory_hot_add_enabled     = optional(bool)
    disk_size_gb               = optional(number)
    firmware                   = optional(string)
    guest_id                   = optional(string)
    adapter_type               = optional(string)
    thin_provisioned           = optional(bool)
    wait_for_guest_ip_timeout  = optional(number)
    wait_for_guest_net_timeout = optional(number)
    domain                     = optional(string)
    ipv4_prefix_length         = optional(number)
    ipv4_gateway               = optional(string)
    dns_servers                = optional(list(string))
    default_user               = optional(string)
    default_user_password      = optional(string)
    ssh_authorized_keys        = optional(list(string))
    extra_cloud_init_userdata  = optional(string, "")
    data_disks = optional(list(object({
      size_gb          = number
      mount_path       = string
      label            = optional(string)
      thin_provisioned = optional(bool, true)
    })), [])
    extra_network_interfaces = optional(list(object({
      network      = string
      ipv4_address = optional(string, "")
      ipv4_netmask = optional(number, 24)
    })), [])
  }))
  default = {}
}
