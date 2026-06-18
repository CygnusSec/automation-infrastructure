# Zabbix Agent Uninstall

This task removes Zabbix Agent 2, legacy Zabbix Agent 1, and any Zabbix server
packages that were accidentally installed on agent targets.

## What It Does

- stops `zabbix-agent2`
- stops `zabbix-agent`
- stops `zabbix-server`
- purges Agent 2 packages
- purges legacy `zabbix-agent`
- purges `zabbix-server`, `zabbix-server-mysql`, and `zabbix-server-pgsql`
- optionally removes the copied local `.deb` repository on each target

## Key Variables

```env
ANSIBLE_ZABBIX_AGENT_TARGET_GROUP=zabbix_agent_targets
ANSIBLE_ZABBIX_AGENT_UNINSTALL_SERVER_PACKAGES="[zabbix-server, zabbix-server-mysql, zabbix-server-pgsql]"
ANSIBLE_ZABBIX_AGENT_UNINSTALL_PACKAGES="[zabbix-agent2, zabbix-agent, zabbix-server, zabbix-server-mysql, zabbix-server-pgsql]"
ANSIBLE_ZABBIX_AGENT_UNINSTALL_SERVICES="[zabbix-agent2, zabbix-agent, zabbix-server]"
ANSIBLE_ZABBIX_AGENT_UNINSTALL_PURGE=true
ANSIBLE_ZABBIX_AGENT_UNINSTALL_AUTOREMOVE=true
ANSIBLE_ZABBIX_AGENT_UNINSTALL_REMOVE_LOCAL_REPO=false
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags zabbix_agent_uninstall
```

Run uninstall and install again:

```bash
./scripts/run-ansible.sh deploy --tags zabbix_agent_uninstall
./scripts/run-ansible.sh deploy --tags zabbix
```
