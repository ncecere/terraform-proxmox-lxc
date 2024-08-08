# terraform-proxmox-lxc

## Proxmox LXC Container Terraform Module

This Terraform module allows you to create and manage LXC containers in a Proxmox environment.

## Prerequisites

- Terraform installed (version 0.12+)
- Access to a Proxmox environment
- Proxmox provider configured

## Usage

1. Create a new Terraform configuration file (e.g., `main.tf`) in your project directory.

2. Use the module in your Terraform configuration:

```hcl
module "proxmox_lxc" {
  source = "./path/to/module"

  # Required variables
  hostname    = "my-lxc-container"
  description = "My LXC container created with Terraform"
  tags        = ["production", "web"]

  # Optional variables (examples of customization)
  cpu_cores   = 2
  memory_mb   = 1024
  
  # Add more variables as needed
}
```

3. Initialize Terraform:

```
terraform init
```

4. Plan and apply the changes:

```
terraform plan
terraform apply
```

## Examples

### Basic LXC Container

```hcl
module "basic_lxc" {
  source = "./path/to/module"

  hostname    = "basic-lxc"
  description = "Basic LXC container"
  tags        = ["test"]

  # Using defaults for other settings
}
```

### Custom LXC Container

```hcl
module "custom_lxc" {
  source = "./path/to/module"

  hostname    = "custom-lxc"
  description = "Custom LXC container with specific configuration"
  tags        = ["production", "database"]

  cpu_cores      = 4
  cpu_units      = 2048
  memory_mb      = 4096
  memory_swap_mb = 2048

  startup_config = {
    order      = "1"
    up_delay   = "30"
    down_delay = "90"
  }

  disks = [
    {
      datastore_id = "local-lvm"
      size         = 20
    }
  ]

  ip_addresses = [
    {
      address = "192.168.1.100/24"
      gateway = "192.168.1.1"
    }
  ]

  create_root_password = true
  create_ssh_keys      = true
}
```

### LXC Container with Custom Authentication

```hcl
module "auth_lxc" {
  source = "./path/to/module"

  hostname    = "auth-lxc"
  description = "LXC container with custom authentication"
  tags        = ["secure"]

  create_root_password = false
  create_ssh_keys      = false
  user_password        = "MySecurePassword123!"
  user_keys            = ["ssh-rsa AAAAB3NzaC1yc2E..."]
}
```

## Variables

See the `variables.tf` file for a complete list of available variables and their descriptions.

## Outputs

- `container_password`: The generated root password (if `create_root_password` is true)
- `container_private_key`: The generated private SSH key (if `create_ssh_keys` is true)
- `container_public_key`: The generated public SSH key (if `create_ssh_keys` is true)

## Notes

- Ensure that you have the necessary permissions in your Proxmox environment to create and manage LXC containers.
- The module will randomly select a node from your Proxmox cluster to create the LXC container.
- Always use secure methods to manage sensitive information like passwords and SSH keys.

## Contributing

Contributions to improve this module are welcome. Please submit issues and pull requests on the project repository.
