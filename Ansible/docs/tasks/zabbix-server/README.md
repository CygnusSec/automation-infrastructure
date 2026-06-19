# Zabbix Server Install

This task installs the Zabbix 7.0 PostgreSQL server packages on the configured
Zabbix server hosts.

## Targeting

Server hosts are read from `env.d/10-inventory.env`:

```env
ANSIBLE_ZABBIX_SERVER_HOSTS=<zabbix-server-ip>
```

The play targets `zabbix_server_targets` by default.

## What It Does

- online mode: downloads the Zabbix 7.0 Ubuntu 24.04 release package, installs
  it with apt, updates apt cache, then installs the configured packages
- offline mode: copies `.deb` files from `repo/zabbix-server` to the target and
  installs them with `apt-get install`
- installs `zabbix-server-pgsql`, `zabbix-frontend-php`, `php8.3-pgsql`,
  `zabbix-nginx-conf`, `zabbix-sql-scripts`, and `zabbix-agent` by default

## Key Variables

Set these in `env.d/30-zabbix-agent.env`:

```env
ANSIBLE_ZABBIX_SERVER_ENABLED=true
ANSIBLE_ZABBIX_SERVER_TARGET_GROUP=zabbix_server_targets
ANSIBLE_ZABBIX_SERVER_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_ZABBIX_SERVER_REPO_SOURCE=./repo/zabbix-server
ANSIBLE_ZABBIX_SERVER_REPO_DEST=/media/installation/zabbix
ANSIBLE_ZABBIX_SERVER_MANAGE_APT_REPO=true
ANSIBLE_ZABBIX_SERVER_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
ANSIBLE_ZABBIX_SERVER_RELEASE_PACKAGE_PATH=/tmp/zabbix-release_latest_7.0+ubuntu24.04_all.deb
ANSIBLE_ZABBIX_SERVER_PACKAGES="[zabbix-server-pgsql, zabbix-frontend-php, php8.3-pgsql, zabbix-nginx-conf, zabbix-sql-scripts, zabbix-agent]"
```

## Offline Bundle

On the online build machine, `./scripts/build-offline-bundle.sh` downloads
server packages into:

```text
Ansible/repo/zabbix-server/
```

The controlling variables live in `env.d/90-offline-bundle.env`:

```env
ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES=true
ANSIBLE_ZABBIX_SERVER_REPO_SOURCE=./repo/zabbix-server
ANSIBLE_ZABBIX_SERVER_OFFLINE_PACKAGES="zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent systemd-sysv"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags zabbix_server
```
