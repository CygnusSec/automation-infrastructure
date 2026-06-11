# vCenter Behavior Test Results

Test date: 2026-04-20

Terraform-managed VM:

- Terraform address: `module.vsphere_vm["test-vcenter-01"].vsphere_virtual_machine.this`
- vCenter name: `vm-vcenter-02`
- UUID: `422d91e2-6b29-8f24-ef4a-4ac4e1c4682b`
- IP: `y.y.y.143`

## 1. CPU/RAM Hot Add

### 1.1 Decrease CPU/RAM to 1 CPU and 1024 MB

Change:

```hcl
num_cpus  = 1
memory_mb = 1024
```

Commands:

```bash
./scripts/run-terraform.sh envs/vcenter plan -no-color
./scripts/run-terraform.sh envs/vcenter apply -auto-approve -no-color
```

Plan result:

```text
~ update in-place
memory   = 2048 -> 1024
num_cpus = 2 -> 1
Plan: 0 to add, 1 to change, 0 to destroy.
```

Apply result:

```text
Modifications complete after 1m1s [id=422d91e2-6b29-8f24-ef4a-4ac4e1c4682b]
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Post-test state from the vCenter API:

```json
{
  "power": {
    "state": "POWERED_ON"
  },
  "cpu": {
    "hot_remove_enabled": false,
    "count": 1,
    "hot_add_enabled": false,
    "cores_per_socket": 1
  },
  "memory": {
    "size_MiB": 1024,
    "hot_add_enabled": false
  }
}
```

Conclusion:

- Terraform/vCenter allowed an in-place CPU/RAM reconfiguration in this case.
- After apply, vCenter still reported the VM as `POWERED_ON`.
- Terraform output did not report VM destroy/create.
- Guest OS reboot status could not be confirmed with uptime because SSH to `ubuntu@y.y.y.143` was rejected with `Permission denied (publickey,password)`.
- This was not a true hot-add test because the operation decreased CPU/RAM.

### 1.2 Check Template and VM After Clone

Template `template_ubuntu_24.04` had hot add enabled:

```json
{
  "cpu": {
    "hot_remove_enabled": false,
    "count": 2,
    "hot_add_enabled": true,
    "cores_per_socket": 1
  },
  "memory": {
    "size_MiB": 2048,
    "hot_add_enabled": true
  }
}
```

The cloned VM did not initially keep that setting:

```json
{
  "cpu": {
    "hot_remove_enabled": false,
    "count": 1,
    "hot_add_enabled": false,
    "cores_per_socket": 1
  },
  "memory": {
    "size_MiB": 1024,
    "hot_add_enabled": false
  }
}
```

The module was updated to set these values explicitly:

```hcl
cpu_hot_add_enabled    = var.cpu_hot_add_enabled
memory_hot_add_enabled = var.memory_hot_add_enabled
```

New defaults:

```hcl
cpu_hot_add_enabled    = true
memory_hot_add_enabled = true
```

### 1.3 Enable Hot Add on an Existing VM

Plan:

```text
cpu_hot_add_enabled    = false -> true
memory_hot_add_enabled = false -> true
Plan: 0 to add, 1 to change, 0 to destroy.
```

Apply:

```text
Modifications complete after 57s [id=422d91e2-6b29-8f24-ef4a-4ac4e1c4682b]
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Power state monitored through the vCenter API during apply:

```text
2026-04-20T22:48:04 POWERED_ON
2026-04-20T22:48:17 POWERED_OFF
2026-04-20T22:48:28 POWERED_ON
```

Conclusion: the first time hot add was enabled on the existing VM, the VM power-cycled.

State after enabling hot add:

```json
{
  "power": {
    "state": "POWERED_ON"
  },
  "cpu": {
    "hot_remove_enabled": false,
    "count": 1,
    "hot_add_enabled": true,
    "cores_per_socket": 1
  },
  "memory": {
    "hot_add_increment_size_MiB": 128,
    "size_MiB": 1024,
    "hot_add_enabled": true,
    "hot_add_limit_MiB": 3072
  }
}
```

### 1.4 Increase CPU/RAM After Hot Add Is Enabled

Change:

```hcl
num_cpus  = 2
memory_mb = 2048
```

Plan:

```text
memory   = 1024 -> 2048
num_cpus = 1 -> 2
Plan: 0 to add, 1 to change, 0 to destroy.
```

Apply:

```text
Modifications complete after 10s [id=422d91e2-6b29-8f24-ef4a-4ac4e1c4682b]
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Power state monitoring did not record any additional state changes after the `POWERED_ON` event from enabling hot add. During the CPU/RAM increase, the VM stayed `POWERED_ON` according to the vCenter API.

Final state:

```json
{
  "power": {
    "state": "POWERED_ON"
  },
  "cpu": {
    "hot_remove_enabled": false,
    "count": 2,
    "hot_add_enabled": true,
    "cores_per_socket": 1
  },
  "memory": {
    "hot_add_increment_size_MiB": 128,
    "size_MiB": 2048,
    "hot_add_enabled": true,
    "hot_add_limit_MiB": 3072
  }
}
```

Conclusion:

- The template had hot add enabled, but before the module change, cloned VMs did not keep the hot-add setting.
- Hot add must be set explicitly in the Terraform resource.
- The first time hot add was enabled on the existing VM, the VM power-cycled.
- After hot add was enabled, increasing CPU/RAM from `1 CPU / 1024 MB` to `2 CPU / 2048 MB` applied successfully without a recorded VM power-off.

## 2. Duplicate IP

Note: the vCenter API did not show any VM reporting IP `y.y.y.160` at test time. To test duplicate IP behavior, a temporary VM was created with the same IP as the existing `vm-vcenter-02`, `y.y.y.143`.

Temporary VM:

```hcl
duplicate-ip-test = {
  vm_name                    = "tf-duplicate-ip-test"
  hostname                   = "tf-duplicate-ip-test"
  ipv4_address               = "y.y.y.143"
  num_cpus                   = 1
  memory_mb                  = 1024
  disk_size_gb               = 25
  wait_for_guest_ip_timeout  = 0
  wait_for_guest_net_timeout = 0
}
```

Plan result:

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Apply result:

```text
Creation complete after 54s [id=422d0c38-e1d4-9c51-5b01-5f17058d8079]
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Temporary VM output:

```text
default_ip_address = null
vm_id              = "422d0c38-e1d4-9c51-5b01-5f17058d8079"
vm_name            = "tf-duplicate-ip-test"
```

The `duplicate-ip-test` block was then removed and apply destroyed the temporary VM:

```text
Destruction complete
Apply complete! Resources: 0 added, 0 changed, 1 destroyed.
```

Conclusion:

- The Terraform provider and vCenter do not validate unique IPs when cloning a VM with a static IP through cloud-init guestinfo.
- The duplicate-IP VM was still created successfully.
- Any duplicate IP issue would be a guest or network operations problem, not a Terraform plan/apply problem.

## 3. VM Exists on ESXi/vCenter but Is Missing from State

Test method that did not modify the real state:

```bash
./scripts/run-terraform.sh envs/vcenter plan -no-color -state=/tmp/tf-empty-state-vcenter-test.tfstate
```

During this plan, VM `vm-vcenter-02` still existed in vCenter, but Terraform used a temporary empty state.

Result:

```text
resource "vsphere_virtual_machine" "this" will be created
name = "vm-vcenter-02"
Plan: 1 to add, 0 to change, 0 to destroy.
```

Conclusion:

- Terraform does not automatically adopt an existing VM only because the configuration is similar.
- If a VM is not in state, Terraform treats it as a new resource to create.
- The correct workflow is to import the VM into state first, or move state when only the Terraform address changes.

For safety, `apply` was not run with the empty state to avoid creating another VM with duplicate name/configuration.

## 4. Incorrect Datastore

Temporary change:

```hcl
datastore = "datastore-does-not-exist"
```

Command:

```bash
./scripts/run-terraform.sh envs/vcenter plan -no-color
```

Result:

```text
Planning failed. Terraform encountered an error while generating this plan.

Error: error fetching datastore: datastore 'datastore-does-not-exist' not found

  with module.vsphere_vm["test-vcenter-01"].data.vsphere_datastore.this,
  on ../../modules/vsphere-vm/main.tf line 19, in data "vsphere_datastore" "this":
  19: data "vsphere_datastore" "this" {
```

Conclusion: an incorrect datastore fails during plan, before Terraform applies anything to vCenter.

## 5. Create a New VM with a Name That Already Exists in vCenter

Temporarily added a new VM to `vms`, using a `vm_name` that already existed in vCenter: `vm-vcenter-02`.

```hcl
duplicate-name-test = {
  vm_name                    = "vm-vcenter-02"
  hostname                   = "duplicate-name-test"
  ipv4_address               = "y.y.y.144"
  num_cpus                   = 1
  memory_mb                  = 1024
  disk_size_gb               = 25
  wait_for_guest_ip_timeout  = 0
  wait_for_guest_net_timeout = 0
}
```

Plan result:

```text
resource "vsphere_virtual_machine" "this" will be created
name = "vm-vcenter-02"
Plan: 1 to add, 0 to change, 0 to destroy.
```

Apply result:

```text
module.vsphere_vm["duplicate-name-test"].vsphere_virtual_machine.this: Creating...

Error: error cloning virtual machine: The name 'vm-vcenter-02' already exists.

  with module.vsphere_vm["duplicate-name-test"].vsphere_virtual_machine.this,
  on ../../modules/vsphere-vm/main.tf line 63, in resource "vsphere_virtual_machine" "this":
  63: resource "vsphere_virtual_machine" "this" {
```

Conclusion:

- Terraform plan did not detect the duplicate VM name in advance.
- vCenter/provider blocked the clone during apply.
- The new VM resource was not created successfully.
- After the test, the `duplicate-name-test` block was removed from tfvars and five temporary data sources were removed from state.

## 6. Increase Disk from 25 GB to 30 GB

Change:

```hcl
disk_size_gb = 30
```

Commands:

```bash
./scripts/run-terraform.sh envs/vcenter plan -no-color
./scripts/run-terraform.sh envs/vcenter apply -auto-approve -no-color
```

Plan result:

```text
~ update in-place
disk.size = 25 -> 30
Plan: 0 to add, 1 to change, 0 to destroy.
```

Apply result:

```text
Modifications complete after 11s [id=422d91e2-6b29-8f24-ef4a-4ac4e1c4682b]
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

Power state monitored through the vCenter API for 120 seconds:

```text
2026-04-20T22:54:36 POWERED_ON
```

No transition to `POWERED_OFF` was recorded during apply.

State after apply:

```text
disk {
  label = "disk0"
  size  = 30
}
power_state = "on"
```

Final plan result:

```text
No changes. Your infrastructure matches the configuration.
```

Conclusion:

- Increasing disk from `25 -> 30 GB` applied in place, without destroy/create.
- In this test, the vCenter API did not record a power-off; the VM stayed `POWERED_ON`.
- Terraform only increased the virtual disk size. Whether the guest OS expands partitions/filesystems automatically depends on cloud-init or guest tooling inside the VM.

## 7. Incorrect Network / Port Group

Temporary change:

```hcl
network = "network-does-not-exist"
```

Command:

```bash
./scripts/run-terraform.sh envs/vcenter plan -no-color
```

Result:

```text
Planning failed. Terraform encountered an error while generating this plan.

Error: Network network-does-not-exist not found

  with module.vsphere_vm["test-vcenter-01"].data.vsphere_network.this,
  on ../../modules/vsphere-vm/main.tf line 24, in data "vsphere_network" "this":
  24: data "vsphere_network" "this" {
```

Conclusion: an incorrect network/port group fails during plan, before Terraform applies anything to vCenter.

## Final Check

After all tests, these values were restored:

```hcl
datastore = "datastore1"
network   = "VM Network"
```

Temporary VM `tf-duplicate-ip-test` was deleted.

The current disk size for `vm-vcenter-02` is `30 GB`.

Command:

```bash
./scripts/run-terraform.sh envs/vcenter plan -no-color
```

Result:

```text
No changes. Your infrastructure matches the configuration.
```
