/* -------------------------------------------------------------------------- */
/*                                   LOCALS                                   */
/* -------------------------------------------------------------------------- */

locals {
  selected_node = one(random_shuffle.node.result)
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


