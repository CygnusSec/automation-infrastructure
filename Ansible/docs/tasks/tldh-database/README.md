# TLDH Database

This task deploys the TLDH MariaDB container as a master/slave pair.

## Target Layout

```text
<database-master-ip>  master
<database-slave-ip>   slave
```

The deployment base directory is:

```text
/opt/tldh-data
```

## What It Does

- creates `/opt/tldh-data`
- creates `/opt/tldh-data/config`
- creates `/mnt/data/mysql`
- renders `docker-compose.yml`
- renders `myV2.cnf`
- renders `docker-entrypoint.sh`
- optionally loads the MariaDB image from a tar file
- starts the container with `docker compose up -d`

The master uses `server-id=1` and `read_only=0`.
The slave uses `server-id=2` and `read_only=1`.

## Required Variables

```env
ANSIBLE_TLDH_DATABASE_ENABLED=true
ANSIBLE_TLDH_DATABASE_TARGET_GROUP=tldh_database_targets
# ANSIBLE_TLDH_DATABASE_MASTER_HOST=<database-master-ip>
# ANSIBLE_TLDH_DATABASE_SLAVE_HOSTS=<database-slave-ip>
ANSIBLE_TLDH_DATABASE_BASE_DIR=/opt/tldh-data
ANSIBLE_TLDH_DATABASE_CONFIG_DIR=/opt/tldh-data/config
ANSIBLE_TLDH_DATABASE_DATA_DIR=/mnt/data/mysql
ANSIBLE_TLDH_DATABASE_IMAGE=registry.bcy.gov.vn/tldh/mariadb:10.7
ANSIBLE_TLDH_DATABASE_ROOT_PASSWORD=
ANSIBLE_TLDH_DATABASE_APP_USER=
ANSIBLE_TLDH_DATABASE_APP_PASSWORD=
ANSIBLE_TLDH_DATABASE_REPLICATION_USER=replica
ANSIBLE_TLDH_DATABASE_REPLICATION_PASSWORD=
```

Store passwords in `.env` on the control machine or in the configured secret
vars file. Do not commit real passwords.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags tldh_database
```

Run only master:

```bash
./scripts/run-ansible.sh deploy --tags tldh_database --limit <database-master-host-or-ip>
```

Run only slave:

```bash
./scripts/run-ansible.sh deploy --tags tldh_database --limit <database-slave-host-or-ip>
```

## Offline Image

If the MariaDB image is not already present on the target hosts, set:

```env
ANSIBLE_TLDH_DATABASE_LOAD_IMAGE=true
ANSIBLE_TLDH_DATABASE_IMAGE_TAR=./repo/docker-images/tldh-mariadb-10.7.tar
```

The role copies the tar file to the target and runs `docker load`.

## Verification

On each target:

```bash
docker ps --filter name=TLDH-Database-production
docker logs TLDH-Database-production-Master
docker logs TLDH-Database-production-Slave
```
