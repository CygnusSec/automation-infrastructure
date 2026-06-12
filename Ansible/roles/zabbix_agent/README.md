# zabbix_agent

Installs and configures Zabbix Agent on Linux targets.

The control machine is expected to be the Zabbix server. Set the server address
with:

```env
ANSIBLE_ZABBIX_SERVER_HOST=192.168.1.10
```

Set the agent hostname globally when needed:

```env
ANSIBLE_ZABBIX_AGENT_HOSTNAME=app-01
```

When `ANSIBLE_ZABBIX_AGENT_HOSTNAME` is empty, the role uses `inventory_hostname`.

Run only this role:

```bash
./scripts/run-ansible.sh deploy.yaml --tags zabbix
```
