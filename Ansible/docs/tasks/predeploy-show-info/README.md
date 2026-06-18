# Predeploy Show Info

This task prints basic facts for the `linux` inventory group before running a
deployment.

## What It Does

- gathers Ansible facts
- prints Ubuntu distribution and version
- prints CPU count and memory size
- prints block device information with `lsblk`

## Command

```bash
cd Ansible
./scripts/run-ansible.sh predeploy-show-info
```

Limit to one group or host when needed:

```bash
./scripts/run-ansible.sh predeploy-show-info --limit zabbix_agent_targets
./scripts/run-ansible.sh predeploy-show-info --limit <target-host-or-ip>
```

## Variables

This playbook uses the inventory connection variables from `.env`, including:

- `ANSIBLE_SSH_USER`
- `ANSIBLE_SSH_PRIVATE_KEY_FILE`
- `ANSIBLE_BECOME`

Normal runs require key-based SSH with a non-root sudo-capable user. Password
SSH is reserved for the `ssh-copy-id` bootstrap playbook only.

## Expected Result

The run should complete with only `ok` tasks and no `changed` tasks.
