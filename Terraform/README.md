# Terraform vCenter Automation

This repository provisions VMware vCenter virtual machines with Terraform through a Docker-based runtime.

It is designed to:

- Clone Linux VMs from existing vCenter templates.
- Pass cloud-init metadata and user data through VMware `guestinfo`.
- Manage multiple VMs from Terraform variable files.
- Preserve the `devops-infra` VM-group/state workflow inside the
  `automation-infrastructure` runtime and CI conventions.
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
- For `data_disks`, the template must also provide `parted`, `e2fsprogs`,
  `util-linux` (`lsblk`, `blkid`, `findmnt`), `udev`, `awk`, and `grep`

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
.dockerignore                  Minimal, secret-safe Docker build context
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

`vms.auto.tfvars.example` is retained only for the legacy single-state mode.
Do not activate it together with grouped `vms/*.tfvars` files.

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
disk_size_gb = null # Preserve the template OS disk size.

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
    num_cpus           = 2
    memory_mb          = 2048
    disk_size_gb       = null
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
- `enable_customization`
- `extra_network_interfaces`
- `data_disks`
- `data_disk_datastore`

Use `ipv4_address = "dhcp"` or leave `ipv4_address` empty to use DHCP for the primary interface.

The environment keeps a compatibility default of 120 GB because the reviewed
`devops-infra` states use 120 GB OS disks. New deployments may set the global
`disk_size_gb = null` to inherit the template size. An explicit value may
expand the disk, but it cannot be smaller than the template disk and Terraform
cannot shrink an existing virtual disk. Never switch an imported group from
120 to null until its template and current state sizes have been compared.

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
    vms-vpn-16.tfvars
    vms-tldh-17.tfvars
    vms-tldh-18.tfvars
    vms-tldh-19.tfvars
    vms-tldh-20.tfvars
  states/
    terraform-vpn-15.tfstate
    terraform-vpn-16.tfstate
    terraform-tldh-17.tfstate
    terraform-tldh-18.tfstate
    terraform-tldh-19.tfstate
    terraform-tldh-20.tfstate
```

The historical real `vms-data.tfvars` is an alternative view of VMs already
owned by TLDH states. It is intentionally excluded from the active tree above;
create a data state only after assigning every VM key to exactly one state.

Prepare a VM group file:

```bash
cp envs/vcenter/vms/vms-tldh-17.tfvars.example envs/vcenter/vms/vms-tldh-17.tfvars
```

Repository examples use sanitized keys and values. They are suitable for new,
disposable states only and are not address-compatible with transferred
production state. For migration, securely transfer the exact real group file
without changing its `vms` map keys.

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

Keep VM map keys unique across active files and states. The historical
`devops-infra` `vms-data.tfvars` file overlaps VM keys already owned by TLDH
groups and has no matching state; treat it as an alternative grouping until
ownership is reconciled. Never apply overlapping groups as separate states.

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

Multi-NIC VMs require `enable_customization = true` so vSphere customization
can map interfaces in their declared order. When customization is enabled,
cloud-init does not render or replace Netplan. When it is disabled, cloud-init
owns the primary interface and extra interfaces are rejected because there is
no stable MAC/interface mapping.

### Additional Data Disks

Use `data_disks` to attach extra disks. On the first clone boot, cloud-init
waits for each disk, rejects multiple/unexpected partitions and non-ext4
filesystems, creates ext4 when needed, and persists the verified mount by UUID.

```hcl
data_disk_datastore = "san-datastore"

data_disks = [
  {
    size_gb          = 100
    mount_path       = "/data"
    label            = "data"
    device           = "/dev/sdb"
    thin_provisioned = true
  }
]
```

`device` is optional. When it is omitted, the module assumes `/dev/sdb` for the
first data disk, `/dev/sdc` for the second, and so on, while skipping the
reserved SCSI unit. At most 14 data disks are supported on the default
controller. Explicit `/dev/sdX`, NVMe, MMC, and `/dev/disk/by-id/...` paths are
accepted; partition suffixes are resolved for each path type.

`data_disk_datastore` is VM-level and applies to every additional disk on that
VM. Omit it or set it to null/empty to let vSphere use the VM's OS datastore.
Changing it for an existing disk may cause a storage move or replacement,
depending on the provider plan, so always review the plan.

Cloud-init `runcmd` is per-instance. Adding `data_disks` to an already-created
VM can attach the VMDK without rerunning the guest mount script. Use the
Ansible `external_disk` role or another idempotent in-guest procedure for
existing VMs; the cloud-init disk workflow is for clone-time initialization.

Choose exactly one disk-configuration owner. If Terraform cloud-init formats
and mounts a disk through `data_disks`, do not run the Ansible `external_disk`
role for that disk. If Ansible owns partitioning/mounting, attach the disk in a
separate Terraform design that does not render a mount action in cloud-init.

## Terraform Workflow

Run Terraform through the Docker wrapper:

```bash
./scripts/run-terraform.sh envs/vcenter validate
./scripts/run-terraform.sh envs/vcenter plan -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter output -state=states/terraform-tldh-17.tfstate
```

The wrapper:

- Loads `.env.compose` when present.
- Falls back to legacy `.env` only when `.env.compose` is missing.
- Builds the local Terraform runtime image if it does not already exist.
- Runs `terraform init`.
- Runs the requested Terraform command.

Docker Compose passes `.env.terraform` into the Terraform container when that file exists.

Run formatting through the same Docker runtime when the host does not have a
local Terraform binary:

```bash
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD:/workspace" \
  -w /workspace \
  terraform-vmware-vcenter-runtime:1.8.5 \
  fmt -recursive
```

Useful state commands:

```bash
./scripts/run-terraform.sh envs/vcenter state list -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter state show -state=states/terraform-tldh-17.tfstate 'module.vsphere_vm["REAL_MAP_KEY"].vsphere_virtual_machine.this'
```

## CI

GitHub Actions runs on pushes to `develop`, `main`, or `master`, pull requests,
and manual dispatch.

The CI workflow checks:

- Terraform formatting with `terraform fmt -check -recursive`
- Parsing and formatting all committed `*.tfvars.example` files
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
./scripts/run-terraform.sh envs/vcenter output -state=states/terraform-tldh-17.tfstate
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
# ARM64 destination:
OFFLINE_PLATFORM=linux/arm64 ./scripts/build-docker-offline-bundle.sh envs/vcenter
```

If a `providers` directory exists and contains Terraform providers, `scripts/run-terraform.sh` configures Terraform to use that local provider mirror.

The offline bundle script reads `.env.compose`, copies both environment examples, and writes the packaged runtime image setting to `.env.compose` inside the generated project.

The bundle deliberately excludes real `.env.terraform`, tfvars, and state
files. Transfer those separately through a secure channel after extraction.
The Terraform build context is also restricted by `.dockerignore`, so local
credentials, states, and provider caches are not sent to the Docker daemon.
The offline image and provider mirror target Linux AMD64 by default. Set
`OFFLINE_PLATFORM=linux/arm64` when the disconnected destination is ARM64.
The regular runtime Dockerfile automatically selects the Terraform binary for
the Docker target architecture (`amd64` or `arm64`).

## Troubleshooting

- Template is missing `open-vm-tools`: Terraform may wait a long time for a guest IP.
- Template is missing the VMware or OVF cloud-init datasource: the VM may be created but cloud-init will not apply guest settings.
- Incorrect `cluster` or `host`: planning may pass, but apply can fail during vCenter lookups.
- `disk_size_gb` is smaller than the template disk: the resource precondition fails during planning.
- Template firmware does not match the configured firmware: the guest may fail to boot.
- Guest network settings are wrong: verify `ipv4_address`, `ipv4_prefix_length`, `ipv4_gateway`, DNS, and port group names.

## Important Files

- `envs/vcenter/terraform.auto.tfvars`
- `envs/vcenter/vms/*.tfvars`
- `envs/vcenter/terraform.auto.tfvars.example`
- `envs/vcenter/vms/*.tfvars.example`
- `.env.compose.example`
- `.env.terraform.example`
- `.dockerignore`
- `scripts/run-terraform.sh`
- `docker-compose.yml`
- `docs/devops-infra-migration.md`
