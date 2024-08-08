/* -------------------------------------------------------------------------- */
/*                            ENVIRONMENT VARIABLES                           */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/*                             REQUIRED VARIABLES                             */
/* -------------------------------------------------------------------------- */

# Basic VM Configuration

variable "hostname" {
  type        = string
  description = "Virtual machine hostname."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,63}$", var.hostname))
    error_message = "The hostname must be a valid DNS hostname, containing only alphanumeric characters and hyphens, and be no longer than 63 characters."
  }
}

variable "description" {
  type        = string
  description = "Description of the virtual machine being created."

  validation {
    condition     = length(var.description) > 0 && length(var.description) <= 255
    error_message = "The description must not be empty and should be no longer than 255 characters."
  }
}

variable "tags" {
  type        = list(string)
  description = "A list of tags to apply to the LXC container. The 'terraform' tag will be automatically added."

  validation {
    condition     = length(var.tags) > 0
    error_message = "At least one tag must be provided."
  }

  validation {
    condition     = alltrue([for tag in var.tags : can(regex("^[a-zA-Z0-9-_]+$", tag))])
    error_message = "Tags must only contain alphanumeric characters, hyphens, and underscores."
  }
}

/* -------------------------------------------------------------------------- */
/*                             OPTIONAL VARIABLES                             */
/* -------------------------------------------------------------------------- */

# Startup Configuration

variable "startup_config" {
  type = object({
    order      = string
    up_delay   = string
    down_delay = string
  })
  default = {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }
  description = "Startup configuration for the VM."
}

# CPU Configuration

variable "cpu_cores" {
  type        = number
  default     = 1
  description = "Number of CPU cores to assign to the VM"

  validation {
    condition     = var.cpu_cores > 0 && var.cpu_cores <= 8
    error_message = "The number of CPU cores must be between 1 and 8."
  }
}

variable "cpu_architecture" {
  type        = string
  default     = "amd64"
  description = "The CPU architecture"

  validation {
    condition     = can(regex("^(amd64|arm64|armhf|i386)$", var.cpu_architecture))
    error_message = "Invalid value for cpu_architecture, only allowed options are: 'amd64', 'arm64', 'armhf', 'i386'"
  }
}

variable "cpu_units" {
  type        = number
  default     = 1024
  description = "CPU weight for a container, must be between 8 and 50000. Number is relative to weights of all the other running containers."

  validation {
    condition     = var.cpu_units >= 8 && var.cpu_units <= 50000
    error_message = "Invalid value for cpu_units, must be between 8 and 50000."
  }
}

# Memory Configuration

variable "memory_mb" {
  type        = number
  default     = 512
  description = "Amount of memory to assign the VM (in megabytes)"

  validation {
    condition     = var.memory_mb >= 512 && var.memory_mb <= 8192
    error_message = "The amount of memory assigned must be between 512 and 8192 megabytes."
  }
}

variable "memory_swap_mb" {
  type        = number
  default     = null
  description = "The swap size in megabytes"
}

# Disk Configuration

variable "disks" {
  type = set(object({
    datastore_id = string
    size         = number
  }))
  default     = []
  description = "The disk configuration for the LXC."
}

# Network Configuration

variable "ip_addresses" {
  type = set(object({
    address = string
    gateway = optional(string)
  }))
  default     = []
  description = "The IPv4 configuration for each network interface"
}

# Authentication Configuration

variable "create_root_password" {
  type        = bool
  default     = false
  description = "Create root password for LXC"
}

variable "create_ssh_keys" {
  type        = bool
  default     = false
  description = "Create SSH keys for root user in LXC."
}

variable "user_keys" {
  type        = list(string)
  default     = []
  description = "The SSH keys for the root account"
  validation {
    condition     = var.create_ssh_keys || length(var.user_keys) > 0
    error_message = "At least one SSH key must be provided when create_ssh_keys is false."
  }
}

variable "user_password" {
  type        = string
  default     = null
  description = "The password for the root account"
  validation {
    condition     = var.create_root_password || (var.user_password != null && length(var.user_password) >= 16)
    error_message = "A password of at least 16 characters must be provided when create_root_password is false."
  }
}
