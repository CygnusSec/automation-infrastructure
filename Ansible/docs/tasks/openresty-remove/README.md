# OpenResty Native Package Remove

Stops and removes the native `openresty` package from selected hosts.

## Target Hosts

Set target hosts in `env.d/10-inventory.env`:

```env
ANSIBLE_OPENRESTY_REMOVE_HOSTS="172.16.3.21,172.16.3.22,172.16.3.23,172.16.3.24,172.16.3.25,172.16.3.26,172.16.3.27,172.16.3.28,172.16.3.31,172.16.3.32,172.16.3.33,172.16.3.34,172.16.3.35,172.16.3.36,172.16.3.37"
```

## Variables

Set role options in `env.d/20-base.env`:

```env
ANSIBLE_OPENRESTY_REMOVE_TARGET_GROUP=openresty_remove_targets
ANSIBLE_OPENRESTY_REMOVE_PACKAGES="[openresty]"
ANSIBLE_OPENRESTY_REMOVE_SERVICES="[openresty]"
ANSIBLE_OPENRESTY_REMOVE_PURGE=false
ANSIBLE_OPENRESTY_REMOVE_AUTOREMOVE=true
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags openresty_remove
```
