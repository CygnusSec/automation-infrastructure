# prerequisite

Ubuntu baseline role.

It validates Ubuntu, installs common packages, applies sysctl values, writes
system limits, disables swap by default, and can optionally disable UFW or set
timezone.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags prerequisite
```

## Key Variables

```env
ANSIBLE_PREREQUISITE_DISABLE_SWAP=true
ANSIBLE_PREREQUISITE_DISABLE_UFW=false
ANSIBLE_PREREQUISITE_TIMEZONE=
ANSIBLE_PREREQUISITE_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_PREREQUISITE_REPO_SOURCE=./repo/prerequisite
ANSIBLE_PREREQUISITE_REPO_DEST=/media/installation/prerequisite
```

## Task Runbook

See [Prerequisite](../../docs/tasks/prerequisite/README.md).
