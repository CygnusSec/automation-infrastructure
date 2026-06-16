# tldh_database

Deploys the TLDH MariaDB container on two hosts:

- `<database-master-ip>`: master
- `<database-slave-ip>`: slave

The deployment path is `/opt/tldh-data`.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags tldh_database
```

Run one node only:

```bash
./scripts/run-ansible.sh deploy --tags tldh_database --limit <target-host-or-ip>
```

## Required Variables

Set secrets in `.env` or in the inventory secret vars file:

```env
ANSIBLE_TLDH_DATABASE_ENABLED=true
# ANSIBLE_TLDH_DATABASE_MASTER_HOST=<database-master-ip>
# ANSIBLE_TLDH_DATABASE_SLAVE_HOSTS=<database-slave-ip>
ANSIBLE_TLDH_DATABASE_ROOT_PASSWORD=
ANSIBLE_TLDH_DATABASE_APP_USER=
ANSIBLE_TLDH_DATABASE_APP_PASSWORD=
ANSIBLE_TLDH_DATABASE_REPLICATION_USER=replica
ANSIBLE_TLDH_DATABASE_REPLICATION_PASSWORD=
```

## Paths

```text
/opt/tldh-data/docker-compose.yml
/opt/tldh-data/config/myV2.cnf
/opt/tldh-data/config/docker-entrypoint.sh
/mnt/data/mysql
```
