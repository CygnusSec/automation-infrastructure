# Apache2 Native Package Remove

Stops and removes native Apache2 packages from selected hosts.

By default this task targets `all_targets`.

## Optional Target Hosts

Set a custom target list in `env.d/10-inventory.env` only when you do not want
to use `all_targets`:

```env
ANSIBLE_APACHE2_REMOVE_HOSTS="172.16.3.21,172.16.3.22"
```

Then set `ANSIBLE_APACHE2_REMOVE_TARGET_GROUP=apache2_remove_targets`.

## Variables

Set role options in `env.d/20-base.env`:

```env
ANSIBLE_APACHE2_REMOVE_TARGET_GROUP=all_targets
ANSIBLE_APACHE2_REMOVE_PACKAGES="[apache2, apache2-bin, apache2-data, apache2-utils]"
ANSIBLE_APACHE2_REMOVE_SERVICES="[apache2]"
ANSIBLE_APACHE2_REMOVE_PURGE=false
ANSIBLE_APACHE2_REMOVE_AUTOREMOVE=true
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags apache2_remove
```
