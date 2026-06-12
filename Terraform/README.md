# Terraform vCenter Automation

This repository provisions VMware vCenter virtual machines with Terraform through a Docker-based runtime.

It is designed to:

- Clone Linux VMs from existing vCenter templates.
- Pass cloud-init metadata and user data through VMware `guestinfo`.
- Manage multiple VMs from Terraform variable files.
- Keep the host machine clean by running Terraform inside Docker.

## Prerequisites

The machine running this repository needs:

- Docker
- Docker Compose
- Network access to vCenter

vCenter needs:

- An account with permission to create, update, and delete VMs
- A datacenter
- A cluster or target ESXi host
- A datastore
- A port group or network
- A Linux template with `cloud-init` and `open-vm-tools`

## Repository Layout

```text
envs/vcenter/                  Terraform environment for vCenter
envs/vcenter/variables.tf      Environment variable definitions
envs/vcenter/*.example         Example variable files
envs/vcenter/vms/              Separate VM group variable files
envs/vcenter/states/           Separate local state files
modules/vsphere-vm/            Reusable VM module
scripts/run-terraform.sh       Docker wrapper for Terraform commands
scripts/build-docker-offline-bundle.sh
docker-compose.yml             Terraform runtime image build/run config
.env.compose.example           Docker Compose/runtime environment example
.env.terraform.example         Terraform environment variable example
```

## Configuration Files

Configuration is split into three groups:

```text
.env.compose                         Docker Compose/runtime settings
.env.terraform                       Terraform variables as TF_VAR_* environment variables
envs/vcenter/*.auto.tfvars           Terraform variables as HCL files
```

Create the local files you need from the examples:

```bash
cp .env.compose.example .env.compose
cp .env.terraform.example .env.terraform
cp envs/vcenter/terraform.auto.tfvars.example envs/vcenter/terraform.auto.tfvars
cp envs/vcenter/vms/vms-tldh-17.tfvars.example envs/vcenter/vms/vms-tldh-17.tfvars
```

Use `.env.compose` for Docker/runtime settings such as `TERRAFORM_IMAGE` and `TERRAFORM_VERSION`.

Use `.env.terraform` for secrets or values you want to inject as Terraform environment variables, for example `TF_VAR_vsphere_password`.

Use `.auto.tfvars` files for normal Terraform configuration. Terraform automatically loads files ending in `.auto.tfvars`.

The main Terraform files you normally edit are:

```text
envs/vcenter/terraform.auto.tfvars
envs/vcenter/vms/*.tfvars
```

## Base vCenter Configuration

Set the common vCenter, inventory, template, compute, network, and guest defaults in `envs/vcenter/terraform.auto.tfvars`.

Example:

```hcl
vsphere_server       = "vcenter.example.local"
vsphere_user         = "administrator@vsphere.local"
vsphere_password     = "change-me"
allow_unverified_ssl = true

datacenter = "Datacenter"
cluster    = "Cluster"
host       = null

datastore     = "datastore1"
network       = "VM Network"
template_name = "template-ubuntu-2404-cloudinit"
folder        = null

num_cpus     = 2
memory_mb    = 2048
disk_size_gb = 50

default_user = "ubuntu"
ssh_authorized_keys = [
  "ssh-rsa AAAA... user@host",
]
```

If VMs are placed directly on an ESXi host instead of a cluster, set `cluster` to `null` and provide `host`:

```hcl
cluster = null
host    = "esxi-host.example.local"
```

If each ESXi host should use a specific datastore, define a host-to-datastore map:

```hcl
host_datastore_map = {
  "x.x.x.15" = "datastore1 (5)"
  "x.x.x.16" = "datastore1 (4)"
  "x.x.x.17" = "datastore1 (3)"
  "x.x.x.18" = "datastore1 (2)"
}
```

When a VM sets `host`, Terraform first checks `host_datastore_map` for that host. If no match exists, it uses the default `datastore`.

The same map can be provided through `.env.terraform` as JSON:

```env
TF_VAR_host_datastore_map={"x.x.x.15":"datastore1 (5)","x.x.x.16":"datastore1 (4)","x.x.x.17":"datastore1 (3)","x.x.x.18":"datastore1 (2)"}
```

If the same variable is set in both `.env.terraform` and an `.auto.tfvars` file, Terraform's normal variable precedence applies; the auto tfvars value overrides the environment variable.

## VM Definitions

VMs are managed through the `vms` map. Keep one vCenter environment in
`envs/vcenter`, then split VM groups into files under `envs/vcenter/vms/`.

Example:

```hcl
vms = {
  test-vcenter-01 = {
    hostname           = "ubuntu-vcenter-01"
    ipv4_address       = "y.y.y.160"
    ipv4_prefix_length = 24
    ipv4_gateway       = "y.y.y.1"
    dns_servers        = ["y.y.y.10", "y.y.y.11"]
    num_cpus           = 2
    memory_mb          = 2048
    disk_size_gb       = 50
  }
}
```

The map key, such as `test-vcenter-01`, is the stable Terraform state identity. Use `vm_name` only when the vCenter VM name must be different from the Terraform identity:

```hcl
vms = {
  test-vcenter-01 = {
    vm_name      = "ubuntu-vcenter-01"
    hostname     = "ubuntu-vcenter-01"
    ipv4_address = "y.y.y.160"
  }
}
```

Common per-VM fields:

- `vm_name`
- `hostname`
- `host`
- `datastore`
- `network`
- `template_name`
- `folder`
- `num_cpus`
- `memory_mb`
- `disk_size_gb`
- `thin_provisioned`
- `cpu_hot_add_enabled`
- `memory_hot_add_enabled`
- `wait_for_guest_ip_timeout`
- `wait_for_guest_net_timeout`
- `ipv4_address`
- `ipv4_prefix_length`
- `ipv4_gateway`
- `dns_servers`
- `default_user`
- `default_user_password`
- `ssh_authorized_keys`
- `extra_cloud_init_userdata`
- `extra_network_interfaces`
- `data_disks`

Use `ipv4_address = "dhcp"` or leave `ipv4_address` empty to use DHCP for the primary interface.

## Separate VM Groups And State

There is only one vCenter environment: `envs/vcenter`. Split VM definitions by
ESXi host, service group, or operational ownership with `-var-file`, and keep a
separate local state file per group with `-state`.

Example:

```text
envs/vcenter/
  terraform.auto.tfvars
  vms/
    vms-vpn-15.tfvars
    vms-tldh-17.tfvars
    vms-tldh-18.tfvars
    vms-data.tfvars
  states/
    terraform-vpn-15.tfstate
    terraform-tldh-17.tfstate
    terraform-tldh-18.tfstate
    terraform-data.tfstate
```

Prepare a VM group file:

```bash
cp envs/vcenter/vms/vms-tldh-17.tfvars.example envs/vcenter/vms/vms-tldh-17.tfvars
```

Put only the ESXi `172.16.9.17` VMs in `envs/vcenter/vms/vms-tldh-17.tfvars`:

```hcl
vms = {
  tldh-17-01 = {
    hostname           = "tldh-17-01"
    host               = "172.16.9.17"
    network            = "APP-SERVER"
    ipv4_address       = "x.x.x.121"
    ipv4_prefix_length = 24
    ipv4_gateway       = "x.x.x.1"
    dns_servers        = ["x.x.x.10", "x.x.x.11"]
  }
}
```

Plan/apply one group:

```bash
./scripts/run-terraform.sh envs/vcenter plan -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
```

Examples by ESXi host:

```bash
# ESXi 172.16.9.17
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate

# ESXi 172.16.9.18
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-tldh-18.tfvars -state=states/terraform-tldh-18.tfstate

# Data VMs with SAN data disks
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-data.tfvars -state=states/terraform-data.tfstate
```

Preview changes:

```bash
./scripts/run-terraform.sh envs/vcenter plan -var-file=vms/vms-vpn-15.tfvars -state=states/terraform-vpn-15.tfstate
```

Destroy only one group:

```bash
# Destroy only VPN on host .15
./scripts/run-terraform.sh envs/vcenter destroy -var-file=vms/vms-vpn-15.tfvars -state=states/terraform-vpn-15.tfstate

# Destroy only TLDH on host .17
./scripts/run-terraform.sh envs/vcenter destroy -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
```

Useful state commands for one group:

```bash
./scripts/run-terraform.sh envs/vcenter state list -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter output -state=states/terraform-tldh-17.tfstate
```

Keep VM map keys unique across files unless you intentionally manage separate
vCenter VM objects with separate state files.

### Additional Network Interfaces

Use `extra_network_interfaces` to attach networks beyond the primary interface:

```hcl
extra_network_interfaces = [
  {
    network      = "APP-SERVER"
    ipv4_address = "y.y.y.2"
    ipv4_netmask = 24
  },
  {
    network      = "VM Network"
    ipv4_address = "x.x.x.2"
    ipv4_netmask = 24
  }
]
```

### Additional Data Disks

Use `data_disks` to attach extra disks. The cloud-init user data partitions, formats, mounts, and persists these disks in `/etc/fstab`.

```hcl
data_disks = [
  {
    size_gb          = 100
    mount_path       = "/data"
    label            = "data"
    thin_provisioned = true
  }
]
```

## Terraform Workflow

Run Terraform through the Docker wrapper:

```bash
./scripts/run-terraform.sh envs/vcenter validate
./scripts/run-terraform.sh envs/vcenter plan
./scripts/run-terraform.sh envs/vcenter apply
./scripts/run-terraform.sh envs/vcenter output
```

The wrapper:

- Loads `.env.compose` when present.
- Falls back to legacy `.env` only when `.env.compose` is missing.
- Builds the local Terraform runtime image if it does not already exist.
- Runs `terraform init`.
- Runs the requested Terraform command.

Docker Compose passes `.env.terraform` into the Terraform container when that file exists.

Useful state commands:

```bash
./scripts/run-terraform.sh envs/vcenter state list
./scripts/run-terraform.sh envs/vcenter state show 'module.vsphere_vm["test-vcenter-01"].vsphere_virtual_machine.this'
```

## CI

GitHub Actions runs on pushes to `main` or `master`, pull requests, and manual dispatch.

The CI workflow checks:

- Terraform formatting with `terraform fmt -check -recursive`
- Terraform initialization and validation for `envs/vcenter`
- Shell syntax for scripts in `scripts/`
- Docker Compose config rendering
- Terraform runtime Docker image build

## Expected Result

After a successful `apply`:

- vCenter has one or more new VMs cloned from the configured template.
- Terraform writes metadata and user data into VM `extra_config`.
- The guest reads `guestinfo` through cloud-init.
- Hostname, IP settings, DNS, user credentials, and SSH keys are configured.
- `open-vm-tools` reports guest IP information back to vCenter.

Check outputs with:

```bash
./scripts/run-terraform.sh envs/vcenter output
```

## Registry or Offline Usage

By default, the repository builds a local Terraform runtime image.

To use a prebuilt image from a private registry:

```bash
cp .env.compose.example .env.compose
```

Then set `TERRAFORM_IMAGE` in `.env.compose`.

To build an offline bundle:

```bash
./scripts/build-docker-offline-bundle.sh envs/vcenter
```

If a `providers` directory exists and contains Terraform providers, `scripts/run-terraform.sh` configures Terraform to use that local provider mirror.

The offline bundle script reads `.env.compose`, copies both environment examples, and writes the packaged runtime image setting to `.env.compose` inside the generated project.

## Troubleshooting

- Template is missing `open-vm-tools`: Terraform may wait a long time for a guest IP.
- Template is missing the VMware or OVF cloud-init datasource: the VM may be created but cloud-init will not apply guest settings.
- Incorrect `cluster` or `host`: planning may pass, but apply can fail during vCenter lookups.
- `disk_size_gb` is smaller than the template disk: apply will fail.
- Template firmware does not match the configured firmware: the guest may fail to boot.
- Guest network settings are wrong: verify `ipv4_address`, `ipv4_prefix_length`, `ipv4_gateway`, DNS, and port group names.

## Important Files

- `envs/vcenter/terraform.auto.tfvars`
- `envs/vcenter/vms.auto.tfvars`
- `envs/vcenter/terraform.auto.tfvars.example`
- `envs/vcenter/vms.auto.tfvars.example`
- `.env.compose.example`
- `.env.terraform.example`
- `scripts/run-terraform.sh`
- `docker-compose.yml`
