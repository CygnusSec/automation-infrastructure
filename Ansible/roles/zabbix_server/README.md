# zabbix_server

Installs Zabbix Server 7.0 packages for PostgreSQL on configured server hosts.

Set the server target IPs in `env.d/10-inventory.env`:

```env
ANSIBLE_ZABBIX_SERVER_HOSTS=<zabbix-server-ip>
```

Configure the task in `env.d/30-zabbix-agent.env`:

```env
ANSIBLE_ZABBIX_SERVER_ENABLED=true
ANSIBLE_ZABBIX_SERVER_TARGET_GROUP=zabbix_server_targets
ANSIBLE_ZABBIX_SERVER_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_ZABBIX_SERVER_REPO_SOURCE=./repo/zabbix-server
ANSIBLE_ZABBIX_SERVER_REPO_DEST=/media/installation/zabbix
ANSIBLE_ZABBIX_SERVER_MANAGE_APT_REPO=true
ANSIBLE_ZABBIX_SERVER_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
ANSIBLE_ZABBIX_SERVER_PACKAGES="[zabbix-server-pgsql, zabbix-frontend-php, php8.3-pgsql, zabbix-nginx-conf, zabbix-sql-scripts, zabbix-agent]"
```

For offline installs, keep `ANSIBLE_ZABBIX_SERVER_INSTALL_FROM_LOCAL_REPO=true`
and put the required `.deb` files under `repo/zabbix-server`. The offline bundle
builder downloads these packages when `ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES=true`
in `env.d/90-offline-bundle.env`.

Run only this role:

```bash
./scripts/run-ansible.sh deploy --tags zabbix_server
```
