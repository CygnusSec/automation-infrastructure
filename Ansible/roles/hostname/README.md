# hostname

Sets the Linux hostname and keeps `/etc/hosts` aligned.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags hostname
```

## Key Variables

```env
ANSIBLE_HOSTNAME_MANAGE=true
ANSIBLE_HOSTNAME_VALUE=ubuntu-app-01
ANSIBLE_HOSTNAME_DOMAIN=lab.local
```

## Task Runbook

See [Hostname](../../docs/tasks/hostname/README.md).
