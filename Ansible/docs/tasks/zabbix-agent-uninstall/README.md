# Zabbix Agent Uninstall

This task removes Zabbix Agent 2, its plugins, and legacy Zabbix Agent 1.

## What It Does

- stops `zabbix-agent2`
- stops `zabbix-agent`
- purges Agent 2 packages
- purges Agent 2 plugin packages
- purges legacy `zabbix-agent`
- optionally removes the copied local `.deb` repository on each target

## Key Variables

```env
ANSIBLE_ZABBIX_AGENT_TARGET_GROUP=zabbix_agent_targets
ANSIBLE_ZABBIX_AGENT_UNINSTALL_PACKAGES="[zabbix-agent2, zabbix-agent2-plugin-mongodb, zabbix-agent2-plugin-mssql, zabbix-agent2-plugin-postgresql, zabbix-agent]"
ANSIBLE_ZABBIX_AGENT_UNINSTALL_SERVICES="[zabbix-agent2, zabbix-agent]"
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

