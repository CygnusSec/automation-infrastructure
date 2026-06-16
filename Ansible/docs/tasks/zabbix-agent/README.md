# Zabbix Agent 2 Install

This task installs and configures Zabbix Agent 2 on the configured agent hosts.

## Current Targeting

The Zabbix server is configured in the local env file:

```text
<zabbix-server-ip-or-dns>
```

Agents are read from:

```env
ANSIBLE_ZABBIX_AGENT_HOSTS=
```

Keep the server IP out of `ANSIBLE_ZABBIX_AGENT_HOSTS` unless you intentionally
want the server to also run an agent.

## What It Does

- stops and removes legacy `zabbix-agent`
- installs `zabbix-agent2`
- installs the MongoDB, MSSQL, and PostgreSQL Agent 2 plugins
- writes `Server=`, `ServerActive=`, and `Hostname=`
- enables and starts `zabbix-agent2`

Keep `ANSIBLE_ZABBIX_AGENT_HOSTNAME=` empty for normal use. With this default,
`Hostname=` is set from each target machine hostname gathered as
`ansible_hostname`. Set a value only when you intentionally want to force the
same hostname for every targeted agent.

## Key Variables

```env
ANSIBLE_ZABBIX_AGENT_ENABLED=true
ANSIBLE_ZABBIX_AGENT_TARGET_GROUP=zabbix_agent_targets
# ANSIBLE_ZABBIX_SERVER_HOST=<zabbix-server-ip-or-dns>
# ANSIBLE_ZABBIX_SERVER_ACTIVE=<zabbix-server-ip-or-dns>
ANSIBLE_ZABBIX_AGENT_HOSTNAME=
ANSIBLE_ZABBIX_AGENT_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_ZABBIX_AGENT_REPO_SOURCE=./repo/zabbix
ANSIBLE_ZABBIX_AGENT_REPO_DEST=/media/installation/zabbix
ANSIBLE_ZABBIX_AGENT_PACKAGES="[zabbix-agent2, zabbix-agent2-plugin-mongodb, zabbix-agent2-plugin-mssql, zabbix-agent2-plugin-postgresql]"
ANSIBLE_ZABBIX_AGENT_SERVICE_NAME=zabbix-agent2
ANSIBLE_ZABBIX_AGENT_CONFIG_FILE=/etc/zabbix/zabbix_agent2.conf
ANSIBLE_ZABBIX_AGENT_REMOVE_LEGACY_AGENT=true
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags zabbix
```

Run only one agent:

```bash
./scripts/run-ansible.sh deploy --tags zabbix --limit <target-host-or-ip>
```

## Offline Notes

Build the offline bundle on an online machine first:

```bash
./scripts/build-offline-bundle.sh
```

The build script downloads Zabbix Agent 2 `.deb` packages into:

```text
Ansible/repo/zabbix/
```
