# Terraform State Files

Local state files for separated VM groups are written here.

Examples:

```text
terraform-vpn-15.tfstate
terraform-vpn-16.tfstate
terraform-tldh-17.tfstate
terraform-tldh-18.tfstate
terraform-tldh-19.tfstate
terraform-tldh-20.tfstate
```

State files are ignored by git. Keep this README only so the directory exists in
the repository.

The historical `terraform-data.tfstate` does not exist in the reviewed source.
Do not create it while the same VM map keys are managed by a TLDH state. A VM
key must have exactly one owning state.
