# MariaDB Native Package Remove

This task removes the native `mariadb-server` package from all configured target
hosts. It does not remove Docker containers, Docker images, or mounted database
data.

## What It Does

- removes `mariadb-server` with apt
- runs apt autoremove
- stays idempotent when `mariadb-server` is not installed

## Key Variables

```env
ANSIBLE_MARIADB_REMOVE_TARGET_GROUP=all_targets
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
