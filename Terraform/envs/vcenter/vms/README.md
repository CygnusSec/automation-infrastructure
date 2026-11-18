# VM Definition Files

Put separate VM groups here as `.tfvars` files.

Examples:

```text
vms-vpn-15.tfvars
vms-vpn-16.tfvars
vms-tldh-17.tfvars
vms-tldh-18.tfvars
vms-tldh-19.tfvars
vms-tldh-20.tfvars
vms-data.tfvars
```

Run a specific group from the Terraform root:

```bash
./scripts/run-terraform.sh envs/vcenter plan -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
```

Each file should define the full `vms` map for that state file.

The committed examples are sanitized teaching inputs for new states. Their map
keys are not substitutes for the real group files and do not match production
state addresses. Preserve exact real map keys during a secure migration.

VM map keys must not appear in more than one active state group. The historical
`devops-infra` checkout contains a `vms-data.tfvars` grouping whose VM keys also
appear in TLDH group files and which has no matching state. Treat that file as
an alternative grouping only; reconcile ownership before creating a data state.
