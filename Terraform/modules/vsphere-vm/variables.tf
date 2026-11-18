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
  default = null

  validation {
    condition     = var.disk_size_gb == null ? true : var.disk_size_gb > 0 && floor(var.disk_size_gb) == var.disk_size_gb
    error_message = "disk_size_gb must be null or a positive whole number."
  }
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

  validation {
    condition     = (var.ipv4_address == "" || lower(var.ipv4_address) == "dhcp") ? true : can(cidrnetmask("${var.ipv4_address}/32"))
    error_message = "ipv4_address must be empty, dhcp, or a valid IPv4 address."
  }
}

variable "ipv4_prefix_length" {
  type    = number
  default = 24

  validation {
    condition     = var.ipv4_prefix_length >= 0 && var.ipv4_prefix_length <= 32 && floor(var.ipv4_prefix_length) == var.ipv4_prefix_length
    error_message = "ipv4_prefix_length must be a whole number from 0 through 32."
  }
}

variable "ipv4_gateway" {
  type    = string
  default = ""

  validation {
    condition     = var.ipv4_gateway == "" ? true : can(cidrnetmask("${var.ipv4_gateway}/32"))
    error_message = "ipv4_gateway must be empty or a valid IPv4 address."
  }
}

variable "dns_servers" {
  type    = list(string)
  default = []

  validation {
    condition = alltrue([
      for server in var.dns_servers :
      can(cidrhost("${server}/32", 0)) || can(cidrhost("${server}/128", 0))
    ])
    error_message = "Each dns_servers entry must be a valid IPv4 or IPv6 address."
  }
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
  description = "Additional data disks to attach to the VM. Each disk specifies size, mount point, optional Linux device path, and optional thin provisioning."
  type = list(object({
    size_gb          = number
    mount_path       = string
    label            = optional(string)
    device           = optional(string)
    thin_provisioned = optional(bool, true)
  }))
  default = []

  validation {
    condition     = alltrue([for disk in var.data_disks : disk.size_gb > 0 && floor(disk.size_gb) == disk.size_gb])
    error_message = "All data_disks entries must have a positive whole-number size_gb."
  }

  validation {
    condition     = alltrue([for disk in var.data_disks : startswith(disk.mount_path, "/") && disk.mount_path != "/"])
    error_message = "All data_disks entries must use an absolute mount_path other than the filesystem root."
  }

  validation {
    condition = alltrue([
      for disk in var.data_disks :
      can(regex("^/([A-Za-z0-9._-]+/)*[A-Za-z0-9._-]+$", disk.mount_path)) &&
      alltrue([for segment in split("/", disk.mount_path) : segment != "." && segment != ".."])
    ])
    error_message = "All data_disks mount_path values must be canonical shell-safe paths without empty, dot, dot-dot, or trailing-slash segments."
  }

  validation {
    condition = alltrue([
      for disk in var.data_disks : disk.device == null ? true : can(regex(
        "^/dev/(sd[b-z]|nvme[0-9]+n[0-9]+|mmcblk[0-9]+|disk/by-id/[A-Za-z0-9._:+-]+)$",
        disk.device
      ))
    ])
    error_message = "When set, data_disks.device must be /dev/sd[b-z], an NVMe/MMC disk, or one shell-safe /dev/disk/by-id entry."
  }

  validation {
    condition     = alltrue([for disk in var.data_disks : disk.device == null ? true : disk.device != "/dev/sda"])
    error_message = "data_disks.device must not be /dev/sda because that path is reserved for the OS disk."
  }

  validation {
    condition     = length(distinct([for disk in var.data_disks : disk.mount_path])) == length(var.data_disks)
    error_message = "data_disks mount_path values must be unique."
  }

  validation {
    condition     = length(distinct([for disk in var.data_disks : disk.device if disk.device != null])) == length([for disk in var.data_disks : disk.device if disk.device != null])
    error_message = "Explicit data_disks device values must be unique."
  }

  validation {
    condition     = length(var.data_disks) <= 14
    error_message = "A single SCSI controller supports at most 14 additional data disks after reserving the OS disk and unit 7."
  }

  validation {
    condition = length(distinct([
      for index, disk in var.data_disks : coalesce(disk.label, "disk${index + 1}")
    ])) == length(var.data_disks)
    error_message = "Effective data_disks labels must be unique."
  }

  validation {
    condition = alltrue([
      for index, disk in var.data_disks :
      coalesce(disk.label, "disk${index + 1}") != "disk0" &&
      !startswith(coalesce(disk.label, "disk${index + 1}"), "orphaned_disk_")
    ])
    error_message = "data_disks labels must not be disk0 or start with orphaned_disk_."
  }
}

variable "extra_network_interfaces" {
  description = "Additional network interfaces beyond the primary. Each specifies network name and optional IP for customization."
  type = list(object({
    network      = string
    ipv4_address = optional(string, "")
    ipv4_netmask = optional(number, 24)
  }))
  default = []

  validation {
    condition = alltrue([
      for nic in var.extra_network_interfaces :
      nic.ipv4_address == "" ? true : can(cidrnetmask("${nic.ipv4_address}/32"))
    ])
    error_message = "Each non-empty extra network interface address must be valid IPv4."
  }

  validation {
    condition = alltrue([
      for nic in var.extra_network_interfaces :
      nic.ipv4_netmask >= 0 && nic.ipv4_netmask <= 32 && floor(nic.ipv4_netmask) == nic.ipv4_netmask
    ])
    error_message = "Each extra network interface netmask must be a whole number from 0 through 32."
  }
}

variable "data_disk_datastore" {
  description = "Datastore for additional data disks. Null or empty uses the OS disk datastore."
  type        = string
  default     = null
}
