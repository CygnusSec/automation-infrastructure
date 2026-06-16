# MariaDB Native Package Remove

This task removes the native `mariadb-server` package from all configured target
hosts. It does not remove Docker containers, Docker images, or mounted database
data.

## What It Does

- stops native MariaDB/MySQL services if present
- removes configured native MariaDB packages with apt
- purges package configuration when enabled
- runs apt autoremove when enabled
- stays idempotent when `mariadb-server` is not installed

## Key Variables

```env
ANSIBLE_MARIADB_REMOVE_TARGET_GROUP=all_targets
ANSIBLE_MARIADB_REMOVE_PACKAGES="[mariadb-server]"
ANSIBLE_MARIADB_REMOVE_SERVICES="[mariadb, mysql]"
ANSIBLE_MARIADB_REMOVE_PURGE=true
ANSIBLE_MARIADB_REMOVE_AUTOREMOVE=true
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags mariadb_remove
```

Preview target hosts before running:

```bash
./scripts/run-ansible.sh deploy --tags mariadb_remove --list-hosts
```
