# Hostname

This task sets Linux hostnames and keeps `/etc/hosts` aligned.

## Key Variables

```env
ANSIBLE_HOSTNAME_MANAGE=true
ANSIBLE_HOSTNAME_VALUE=app-01
ANSIBLE_HOSTNAME_DOMAIN=bcy.gov.vn
```

`ANSIBLE_HOSTNAME_VALUE` applies globally. Use inventory host variables if
different hosts need different hostnames.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags hostname
```

## Verification

```bash
./scripts/run-ansible.sh predeploy-show-info --limit linux
```

Or SSH to a target:

```bash
hostnamectl
cat /etc/hosts
```

