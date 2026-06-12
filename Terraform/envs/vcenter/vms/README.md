# VM Definition Files

Put separate VM groups here as `.tfvars` files.

Examples:

```text
vms-vpn-15.tfvars
vms-tldh-17.tfvars
vms-tldh-18.tfvars
vms-data.tfvars
```

Run a specific group from the Terraform root:

```bash
./scripts/run-terraform.sh envs/vcenter plan -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
```

Each file should define the full `vms` map for that state file.
