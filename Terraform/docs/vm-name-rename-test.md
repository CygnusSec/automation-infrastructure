# Test Case: Rename a vCenter VM with `vm_name`

Test date: 2026-04-20

## Goal

Verify that the `vms` map key is separated from the VM name shown in vCenter:

- The `vms` map key is the stable identity in Terraform state.
- The `vm_name` field is the display name in vCenter.
- Changing `vm_name` must not make Terraform destroy and recreate the VM.

## Code Changes

- `envs/vcenter/main.tf`
  - `vm_name = coalesce(each.value.vm_name, each.key)`
  - `instance_id = each.key`
- `envs/vcenter/variables.tf`
  - Added `vm_name = optional(string)` to the `vms` object.
- `modules/vsphere-vm`
  - Added the `instance_id` variable.
  - Cloud-init metadata uses `coalesce(var.instance_id, var.vm_name)`.

Reason for separating `instance_id`: renaming a VM in vCenter should not change the cloud-init instance ID to the new VM name.

## Test Configuration

Managed VM:

```hcl
vms = {
  test-vcenter-01 = {
    hostname     = "test-vcenter-01"
    ipv4_address = "y.y.y.143"
    num_cpus     = 2
    memory_mb    = 2048
    disk_size_gb = 25
  }
}
```

Temporary change:

```hcl
vms = {
  test-vcenter-01 = {
    vm_name      = "test-vcenter-01-rename-test"
    hostname     = "test-vcenter-01"
    ipv4_address = "y.y.y.143"
    num_cpus     = 2
    memory_mb    = 2048
    disk_size_gb = 25
  }
}
```

## Test Results

Command:

```bash
./scripts/run-terraform.sh envs/vcenter plan -no-color
```

Key result:

```text
~ update in-place
name = "test-vcenter-01" -> "test-vcenter-01-rename-test"
Plan: 0 to add, 1 to change, 0 to destroy.
```

Command:

```bash
./scripts/run-terraform.sh envs/vcenter apply -auto-approve -no-color
```

Key result:

```text
Modifications complete after 45s [id=422d91e2-6b29-8f24-ef4a-4ac4e1c4682b]
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
vm_name = "test-vcenter-01-rename-test"
```

The test `vm_name` value was then removed to rename the VM back to its original name.

Revert apply result:

```text
name = "test-vcenter-01-rename-test" -> "test-vcenter-01"
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
vm_id = "422d91e2-6b29-8f24-ef4a-4ac4e1c4682b"
vm_name = "test-vcenter-01"
```

Final check:

```bash
./scripts/run-terraform.sh envs/vcenter validate
./scripts/run-terraform.sh envs/vcenter plan -no-color
```

Result:

```text
Success! The configuration is valid.
No changes. Your infrastructure matches the configuration.
```

## Conclusion

The `vm_name` separation works with the current vCenter and Terraform provider behavior. Changing `vm_name` renames the existing VM in place, without destroy/create, and the VM UUID remains unchanged.

Note: changing the `vms` map key still changes the Terraform resource address. To use a truly stable key, create VMs with a pattern like this:

```hcl
vms = {
  vm01 = {
    vm_name      = "test-vcenter-01"
    hostname     = "test-vcenter-01"
    ipv4_address = "y.y.y.143"
  }
}
```

Later, change only `vm_name`; do not change the `vm01` key.
