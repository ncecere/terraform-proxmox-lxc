/* -------------------------------------------------------------------------- */
/*                                   LOCALS                                   */
/* -------------------------------------------------------------------------- */

locals {
  # Default network interface configuration
  default_network_interface = {
    bridge = "vmbr0"
    # Additional optional settings:
    # enabled     = true
    # firewall    = false
    # mac_address = null
    # mtu         = null
    # name        = "veth"
    # rate_limit  = null
    # vlan_id     = null
  }

  # Calculate swap size based on memory
  swap_size = (
    var.memory_mb <= 2048 ? var.memory_mb * 2 :
    var.memory_mb <= 4096 ? var.memory_mb :
    var.memory_mb <= 16384 ? var.memory_mb / 2 :
    4096
  )

  # Merge user-provided network interface settings with defaults
  network_interfaces = [for network_interface in var.network_interface : merge(local.default_network_interface, network_interface)]

  # Select a single node from the randomly shuffled list
  selected_node = one(random_shuffle.node.result)
}

/* -------------------------------------------------------------------------- */
/*                            PROXMOX NODE SELECTION                          */
/* -------------------------------------------------------------------------- */

# Fetch all available nodes in the Proxmox cluster
data "proxmox_virtual_environment_nodes" "available_nodes" {}

# Randomly select one node from the available nodes
resource "random_shuffle" "node" {
  input        = data.proxmox_virtual_environment_nodes.available_nodes.names
  result_count = 1
}

/* -------------------------------------------------------------------------- */
/*                              SECRETS GENERATION                            */
/* -------------------------------------------------------------------------- */

# Generate a random password if create_root_password is true
resource "random_password" "create" {
  count            = var.create_root_password ? 1 : 0
  length           = 32
  override_special = "_%@"
  special          = true
}

# Generate SSH keys if create_ssh_keys is true
resource "tls_private_key" "create" {
  count     = var.create_ssh_keys ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

/* -------------------------------------------------------------------------- */
/*                                 LXC RESOURCE                               */
/* -------------------------------------------------------------------------- */

resource "proxmox_virtual_environment_container" "lxc" {
  name        = var.hostname
  description = var.description
  tags        = local.normalized_tags
  node_name   = local.selected_node

  # Startup configuration
  startup {
    order      = var.startup_config.order
    up_delay   = var.startup_config.up_delay
    down_delay = var.startup_config.down_delay
  }

  # CPU configuration
  cpu {
    architecture = var.cpu_architecture
    cores        = var.cpu_cores
    units        = var.cpu_units
  }

  # Memory configuration
  memory {
    dedicated = var.memory_mb
    swap      = var.memory_swap_mb != null ? var.memory_swap_mb : local.swap_size
  }

  # Operating system configuration
  operating_system {
    template_file_id = "${var.template_datastore}:vztmpl/${var.template_name}"
    type             = var.template_type
  }

  # Data disks configuration
  dynamic "disk" {
    for_each = var.disks
    iterator = "disk"
    content {
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
    }
  }

  # Network interfaces configuration
  dynamic "network_interface" {
    for_each = { for idx, network_interface in local.network_interfaces : idx => network_interface }
    content {
      bridge = network_interface.value.bridge
      name   = "veth${network_interface.key}"
    }
  }

  # Initialization configuration
  initialization {
    # DNS configuration
    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    # IP configuration
    ip_config {
      # IPv4 configuration
      dynamic "ipv4" {
        for_each = var.ip_addresses != null ? var.ip_addresses : []
        content {
          address = ipv4.value.address
          gateway = ipv4.value.gateway
        }
      }

      # DHCP fallback if no IP addresses are provided
      dynamic "ipv4" {
        for_each = var.ip_addresses == null ? [1] : []
        content {
          address = "dhcp"
        }
      }

      # User account configuration
      user_account {
        keys     = var.user_keys != null ? var.user_keys : [trimspace(tls_private_key.create[0].public_key_openssh)]
        password = var.user_password != null ? var.user_password : random_password.create[0].result
      }
    }
  }
}

/* -------------------------------------------------------------------------- */
/*                                   OUTPUTS                                  */
/* -------------------------------------------------------------------------- */

output "container_password" {
  value     = var.create_root_password ? random_password.create[0].result : null
  sensitive = true
}

output "container_private_key" {
  value     = var.create_ssh_keys ? tls_private_key.create[0].private_key_pem : null
  sensitive = true
}

output "container_public_key" {
  value = var.create_ssh_keys ? tls_private_key.create[0].public_key_openssh : null
}
