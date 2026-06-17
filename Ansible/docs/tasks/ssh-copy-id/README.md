# SSH Key Bootstrap

This task installs the Ansible public key on target servers. It is intended for
the first run when the targets are still reachable only by SSH password.

## What It Does

- validates that the public key file exists on the control machine
- connects to `ssh_copy_id_targets`
- installs the public key for `ANSIBLE_SSH_USER`

## Required Variables

```env
ANSIBLE_SSH_USER=bcy_admin
ANSIBLE_SSH_PRIVATE_KEY_FILE=./inventories/customer-a/secrets/id_rsa
ANSIBLE_SSH_COPY_ID_PUBLIC_KEY_FILE=./inventories/customer-a/secrets/id_rsa.pub
ANSIBLE_SSH_COPY_ID_TARGET_GROUP=ssh_copy_id_targets
ANSIBLE_SSH_PASSWORD_AUTH=true
ANSIBLE_SSH_COMMON_ARGS="-o PubkeyAuthentication=no -o PreferredAuthentications=password"
ANSIBLE_PASSWORD=your-ssh-password
```

Set `ANSIBLE_BECOME_PASSWORD` only if the target requires sudo for later tasks.
The SSH key bootstrap playbook itself runs with `become: false`.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh ssh-copy-id
```

Run against one target while testing:

```bash
./scripts/run-ansible.sh ssh-copy-id --limit <target-host-or-ip>
```

## After Success

Switch back to key-based SSH:

```env
ANSIBLE_SSH_PASSWORD_AUTH=
ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE=
ANSIBLE_SSH_COMMON_ARGS=
ANSIBLE_PASSWORD=
```

Then verify:

```bash
./scripts/run-ansible.sh predeploy-show-info --limit ssh_copy_id_targets
```
