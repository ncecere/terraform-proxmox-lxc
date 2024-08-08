/* -------------------------------------------------------------------------- */
/*                                   LOCALS                                   */
/* -------------------------------------------------------------------------- */

locals {
  # Default configurations
  default_network_interface = {
    bridge = "vmbr0"
    # enabled     = true
    # firewall    = false
    # mac_address = null
    # mtu         = null
    # name        = "veth"
    # rate_limit  = null
    # vlan_id     = null
  }

  swap_size = (
    var.memory_mb <= 2048 ? var.memory_mb * 2 :
    var.memory_mb <= 4096 ? var.memory_mb :
    var.memory_mb <= 16384 ? var.memory_mb / 2 :
    4096
  )

  network_interfaces = [for network_interface in var.network_interface : merge(local.default_network_interface, network_interface)]
  selected_node      = one(random_shuffle.node.result)
}

/* -------------------------------------------------------------------------- */
/*                            PROXMOX NODE SELECTION                          */
/* -------------------------------------------------------------------------- */

# Return all nodes in the proxmox cluster
data "proxmox_virtual_environment_nodes" "available_nodes" {}

# Choose a random node from the cluster
resource "random_shuffle" "node" {
  input        = data.proxmox_virtual_environment_nodes.available_nodes.names
  result_count = 1
}

/* -------------------------------------------------------------------------- */
/*                              SECRETS SELECTION                             */
/* -------------------------------------------------------------------------- */

resource "random_password" "create" {
  count            = var.create_root_password == true ? 1 : 0
  length           = 32
  override_special = "_%@"
  special          = true
}

resource "tls_private_key" "create" {
  count     = var.create_ssh_keys == true ? 1 : 0
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

  node_name = local.selected_node

  startup {
    order      = var.startup_config.order
    up_delay   = var.startup_config.up_delay
    down_delay = var.startup_config.down_delay
  }

  cpu {
    architecture = var.cpu_architecture
    cores        = var.cpu_cores
    units        = var.cpu_units
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.memory_swap_mb != null ? var.memory_swap_mb : local.swap_size
  }

  operating_system {
    template_file_id = "${var.template_datastore}:vztmpl/${var.template_name}"
    type             = var.template_type

  }

  # DATA disks
  dynamic "disk" {
    for_each = var.disks
    iterator = "disk"
    content {
      datastore_id = disk.value.datastore_id
      size         = disk.value.size
    }
  }

  dynamic "network_interface" {
    for_each = { for idx, network_interface in local.network_interfaces : idx => network_interface }
    content {
      bridge = network_interface.value.bridge
      name   = "veth${network_interface.key}"
    }
  }

  initialization {
    # DNS configuration
    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    # IP configuration
    ip_config {
      dynamic "ipv4" {
        for_each = var.ip_addresses != null ? var.ip_addresses : []
        content {
          address = ipv4.value.address
          gateway = ipv4.value.gateway
        }
      }

      dynamic "ipv4" {
        for_each = var.ip_addresses == null ? [1] : []
        content {
          address = "dhcp"
        }
      }

      user_account {
        keys     = var.user_keys != null ? var.user : [trimspace(tls_private_key.create.public_key_openssh)]
        password = var.user_password != null ? var.user_password : random_password.create.result
      }

    }
  }
}

output "container_password" {
  value     = random_password.create.result
  sensitive = true
}

output "container_private_key" {
  value     = tls_private_key.create.private_key_pem
  sensitive = true
}

output "container_public_key" {
  value = tls_private_key.create.public_key_openssh
}
