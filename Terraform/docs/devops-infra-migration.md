# devops-infra Integration Record

This document records how the standalone `devops-infra` Terraform stack was
integrated into `automation-infrastructure/Terraform` without copying local
credentials, state, or generated artifacts.

## Source Snapshot

- Repository: `devops-infra`
- Branch: `terraform-vcenter-improve`
- Base commit: `2780743c9a7724e7fcda585dce9cd7f9f718ef4d`
- Integration review date: 2026-11-18
- Local source changes reviewed: `README.md`, `envs/vcenter/main.tf`,
  `envs/vcenter/variables.tf`, `modules/vsphere-vm/main.tf`,
  `modules/vsphere-vm/templates/userdata.yaml.tftpl`, and
  `modules/vsphere-vm/variables.tf`

The destination already contained the committed standalone baseline. The
integration therefore merged the current behavior into the destination layout
instead of replacing the directory wholesale.

## Source-to-Destination Mapping

| Standalone source | Integrated destination | Decision |
|---|---|---|
| `envs/vcenter/` | `Terraform/envs/vcenter/` | Preserve the environment/module interface and add nullable OS disk plus data-disk datastore support. |
| `modules/vsphere-vm/` | `Terraform/modules/vsphere-vm/` | Preserve destination validation and explicit device support while merging current source behavior. |
| `scripts/` | `Terraform/scripts/` | Keep destination wrappers because they support split env files, state directories, ownership repair, and standalone offline packaging. |
| `.env.example` | `.env.compose.example` and `.env.terraform.example` | Split runtime/image settings from Terraform input variables and credentials. |
| `docker-compose.yml` and `docker/` | `Terraform/docker-compose.yml` and `Terraform/docker/` | Preserve the destination version; the Terraform runtime remains 1.8.5. |
| `README.md` | `Terraform/README.md` | Merge operational behavior into the generic destination guide; do not replace it with environment-specific topology. |
| VM group layout | `Terraform/envs/vcenter/vms/` and `states/` | Preserve one var-file and one state file per owning group. |

## Integrated Behavior

- The reusable module accepts a null `disk_size_gb` to inherit the template OS
  disk. The environment keeps a 120 GB compatibility default for imported
  `devops-infra` states; new groups can explicitly set the global value to null.
- Per-VM `data_disk_datastore` can place additional disks on a separate
  datastore.
- Extra data disks preserve optional explicit guest device paths and validated
  automatic `/dev/sd[b-o]` defaults.
- Cloud-init waits for disks, refuses unexpected existing layouts/filesystems,
  and persists ext4 mounts by UUID.
- `enable_customization` is available globally and per VM. vSphere
  customization owns networking when enabled and metadata explicitly disables
  cloud-init networking; cloud-init owns only the primary interface when
  customization is disabled.
- VM groups cover the standalone host layout while retaining sanitized example
  values.

The standalone source declared a `power_on` variable, but the vSphere provider
exposes only computed `power_state` for this resource. The unused variable was
not carried into the public interface.

The source also contained a commented SSH `remote-exec` disk-mount block. It
was not copied because it is non-executable, duplicates the cloud-init path,
and depends on guest password SSH. Existing VMs must use an explicit
idempotent in-guest procedure such as the Ansible `external_disk` role; changing
guestinfo does not rerun clone-time cloud-init `runcmd`.

## Intentionally Excluded

The following are runtime or sensitive artifacts, not source code, and must not
be committed or placed in an offline source bundle:

- `.env`, `.env.compose`, and `.env.terraform`
- real `*.tfvars` files
- `*.tfstate` and backup files
- `.terraform/`, provider mirrors, and Docker caches
- editor/assistant metadata and `.DS_Store`
- the untracked generated VM inventory containing environment topology

Move required runtime files through an approved secure channel. A standalone
source `.env` containing `TF_VAR_*` values maps to destination
`.env.terraform`, not to legacy `.env`.

## State Ownership Warning

The reviewed standalone checkout has 53 VM entries across seven real VM
var-files, representing 45 unique map keys after removing eight duplicates in
`vms-data.tfvars`. There are only six main state files. `vms-data.tfvars` has no
matching data state and is an alternative grouping, not an additional
deployable state.

Committed `*.tfvars.example` files are sanitized one-VM samples. Their map keys
do not match production state addresses and they do not represent a migrated
runtime inventory. Move the exact seven real var-files and the six matching
states through an approved secure channel; never pair an example file with a
copied production state.

Five source groups have matching configuration/state VM counts. The real
`vms-tldh-20.tfvars` contains two map keys while its state contains only one VM
instance (the other resource entry has zero instances). A plan for that group
is expected to propose one create and requires explicit operator approval.

Before any apply:

1. Back up and checksum each existing state file.
2. Copy only the state associated with the selected VM group.
3. Compare the configured map keys with `terraform state list`.
4. Preserve or backfill `disk_size_gb = 120` for existing VMs before considering
   a global null/template-size policy; all reviewed source states have 120 GB
   OS disks.
5. Run a plan with the matching `-var-file` and `-state` arguments.
6. Reject any unintended destroy, replacement, disk shrink, or duplicate VM
   creation.

The module name and `for_each` state addresses are unchanged, so relocating the
source tree does not itself require `terraform state mv`. Running without the
original state would make existing VMs appear unmanaged and must not be
followed by apply.

## Validation Gates

Run these commands from `automation-infrastructure/Terraform`:

```bash
terraform fmt -check -recursive
terraform -chdir=envs/vcenter init -backend=false -lockfile=readonly
terraform -chdir=envs/vcenter validate
bash scripts/check-tfvars-examples.sh
docker compose --env-file .env.compose.example config --quiet
bash -n scripts/run-terraform.sh scripts/build-docker-offline-bundle.sh scripts/check-tfvars-examples.sh
```

A disposable VM should be used for the first live verification of multi-NIC,
separate data datastore, cloud-init disk mounting, and idempotent second apply.
