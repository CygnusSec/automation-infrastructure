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
./scripts/run-ansible.sh predeploy-show-info --limit 172.16.3.21
```

## Variables

This playbook uses the inventory connection variables from `.env`, including:

- `ANSIBLE_SSH_USER`
- `ANSIBLE_SSH_PRIVATE_KEY_FILE`
- `ANSIBLE_SSH_PASSWORD_AUTH`
- `ANSIBLE_BECOME`

## Expected Result

The run should complete with only `ok` tasks and no `changed` tasks.

