# zabbix_agent

Installs and configures Zabbix Agent 2 on Linux targets.

The control machine is expected to be the Zabbix server. Set the server address
with:

```env
ANSIBLE_ZABBIX_SERVER_HOST=192.168.1.10
```

Set the agent hostname globally when needed:

```env
ANSIBLE_ZABBIX_AGENT_HOSTNAME=app-01
```

When `ANSIBLE_ZABBIX_AGENT_HOSTNAME` is empty, the role uses the target machine
hostname from `ansible_hostname`, falling back to `inventory_hostname` only if
facts are not available.

Default packages:

```env
ANSIBLE_ZABBIX_AGENT_PACKAGES=[zabbix-agent2, zabbix-agent2-plugin-mongodb, zabbix-agent2-plugin-mssql, zabbix-agent2-plugin-postgresql]
ANSIBLE_ZABBIX_AGENT_SERVICE_NAME=zabbix-agent2
ANSIBLE_ZABBIX_AGENT_CONFIG_FILE=/etc/zabbix/zabbix_agent2.conf
```

For online installs, the role can install the Zabbix 7.0 Ubuntu 24.04 release
package before installing Agent 2:

```env
ANSIBLE_ZABBIX_AGENT_MANAGE_APT_REPO=true
ANSIBLE_ZABBIX_AGENT_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
```

For offline installs, put the required `.deb` files under `repo/zabbix` and set:

```env
ANSIBLE_ZABBIX_AGENT_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_ZABBIX_AGENT_REPO_SOURCE=./repo/zabbix
ANSIBLE_ZABBIX_AGENT_REPO_DEST=/media/installation/zabbix
```

The role stops and removes legacy `zabbix-agent` before installing Agent 2 by
default:

```env
ANSIBLE_ZABBIX_AGENT_REMOVE_LEGACY_AGENT=true
ANSIBLE_ZABBIX_AGENT_LEGACY_PACKAGES=[zabbix-agent]
ANSIBLE_ZABBIX_AGENT_LEGACY_SERVICES=[zabbix-agent]
```

Run only this role:

```bash
./scripts/run-ansible.sh deploy --tags zabbix
```

Uninstall Agent 2 and legacy Agent 1 packages:

```bash
./scripts/run-ansible.sh deploy --tags zabbix_agent_uninstall
```

## Task Runbooks

- [Zabbix Agent 2 Install](../../docs/tasks/zabbix-agent/README.md)
- [Zabbix Agent Uninstall](../../docs/tasks/zabbix-agent-uninstall/README.md)
