# Split Environment Files

`scripts/build-offline-bundle.sh` loads environment variables in this order:

1. `.env`
2. `env.d/*.env` in alphabetic order

`scripts/run-ansible.sh` loads `.env` first. When you run with `--tags`, it then
loads `env.d/10-inventory.env` plus the env file mapped to those tags. When you
run without `--tags`, it loads all `env.d/*.env` files.

Use `.env` for common settings such as runtime image, SSH user, and secrets.
Use `env.d/*.env` for task-specific settings.

Real `env.d/*.env` files are ignored by git. The tracked `*.env.example` files
are templates.

## Create Task Environment Files

Copy only the task files you need:

```bash
cp env.d/10-inventory.env.example env.d/10-inventory.env
cp env.d/30-zabbix-agent.env.example env.d/30-zabbix-agent.env
cp env.d/70-tldh-database.env.example env.d/70-tldh-database.env
```

Files loaded later override variables from earlier files. Prefix filenames with
numbers to keep the order predictable.

## Common Layout

```text
.env                         # common runtime, SSH, and secrets
env.d/10-inventory.env       # host lists and inventory groups
env.d/20-base.env            # prerequisite, Docker, iptables, MariaDB cleanup
env.d/25-host-network.env    # hostname and network
env.d/30-zabbix-agent.env    # Zabbix Server and Agent 2
env.d/40-dns-time.env        # DNS/time services and NTP clients
env.d/50-external-disk.env   # external disk mounts
env.d/60-docker-swarm.env    # Docker Swarm
env.d/70-tldh-database.env   # TLDH database master/slave
env.d/90-offline-bundle.env  # online build/offline bundle settings
```

## Tag Mapping

| Tags | Env file |
| --- | --- |
| `base`, `prerequisite`, `docker`, `iptable`, `iptables`, `iptable_block`, `iptables_block`, `mariadb_remove` | `20-base.env` |
| `hostname`, `network` | `25-host-network.env` |
| `zabbix`, `zabbix_server`, `zabbix_agent`, `zabbix_agent_uninstall` | `30-zabbix-agent.env` |
| `dns_time_services`, `dns_server`, `time_server`, `ntp_client` | `40-dns-time.env` |
| `external_disk` | `50-external-disk.env` |
| `docker_swarm`, `docker_swarm_leave`, `docker_swarm_iptables` | `60-docker-swarm.env` |
| `tldh_database` | `70-tldh-database.env` |
