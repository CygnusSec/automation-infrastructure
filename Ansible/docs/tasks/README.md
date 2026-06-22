# Ansible Task Runbooks

Each task runbook describes one operational action, the variables it uses, and
the exact command to run it through `scripts/run-ansible.sh`.

Run all commands from the `Ansible/` directory unless the runbook says
otherwise.

Environment values can stay in `.env`, or be split into task-specific
`env.d/*.env` files. The runner loads `.env` first and then `env.d/*.env` in
alphabetic order.

## Task Index

| Task | Purpose | Main command |
| --- | --- | --- |
| [Predeploy Show Info](predeploy-show-info/README.md) | Print OS, CPU, memory, and disk facts before deployment. | `./scripts/run-ansible.sh predeploy-show-info` |
| [SSH Key Bootstrap](ssh-copy-id/README.md) | Install the Ansible public key using password SSH for the first run. | `./scripts/run-ansible.sh ssh-copy-id` |
| [Base Preparation](base/README.md) | Run prerequisite and Docker roles together. | `./scripts/run-ansible.sh deploy --tags base` |
| [Prerequisite](prerequisite/README.md) | Validate Ubuntu, install baseline packages, sysctl, limits, swap, timezone, UFW. | `./scripts/run-ansible.sh deploy --tags prerequisite` |
| [Docker](docker/README.md) | Install Docker and Docker Compose v2. | `./scripts/run-ansible.sh deploy --tags docker` |
| [iptables](iptables/README.md) | Add common loopback, SSH, service source, and external service ACCEPT rules. | `./scripts/run-ansible.sh deploy --tags iptables` |
| [iptables Block](iptables/README.md) | Set `INPUT` and `OUTPUT` policies to `DROP` after allow rules are ready. | `./scripts/run-ansible.sh deploy --tags iptables_block` |
| [Hostname](hostname/README.md) | Set Linux hostnames and `/etc/hosts`. | `./scripts/run-ansible.sh deploy --tags hostname` |
| [Network](network/README.md) | Apply static Netplan settings. | `./scripts/run-ansible.sh deploy --tags network` |
| [Zabbix Server Install](zabbix-server/README.md) | Install Zabbix Server packages for PostgreSQL. | `./scripts/run-ansible.sh deploy --tags zabbix_server` |
| [Zabbix Agent 2 Install](zabbix-agent/README.md) | Install and configure Zabbix Agent 2. | `./scripts/run-ansible.sh deploy --tags zabbix` |
| [Zabbix Agent Uninstall](zabbix-agent-uninstall/README.md) | Remove Agent 2, legacy Agent 1, and accidental Zabbix server packages from agent targets. | `./scripts/run-ansible.sh deploy --tags zabbix_agent_uninstall` |
| [MariaDB Native Package Remove](mariadb-remove/README.md) | Remove native `mariadb-server` apt package from targets. | `./scripts/run-ansible.sh deploy --tags mariadb_remove` |
| [DNS And Time Services](dns-time-services/README.md) | Deploy DNS and time server containers together. | `./scripts/run-ansible.sh deploy --tags dns_time_services` |
| [DNS Server](dns-server/README.md) | Deploy only the BIND DNS container. | `./scripts/run-ansible.sh deploy --tags dns_server` |
| [Time Server](time-server/README.md) | Deploy only the Chrony time server container. | `./scripts/run-ansible.sh deploy --tags time_server` |
| [NTP Client](ntp-client/README.md) | Point targets to the internal time servers. | `./scripts/run-ansible.sh deploy --tags ntp_client` |
| [TLDH Database](tldh-database/README.md) | Deploy MariaDB master/slave containers. | `./scripts/run-ansible.sh deploy --tags tldh_database` |
| [External Disk](external-disk/README.md) | Partition, format, mount, and persist an external disk. | `./scripts/run-ansible.sh deploy --tags external_disk` |
| [Docker Swarm](docker-swarm/README.md) | Initialize Swarm and join worker nodes. | `./scripts/run-ansible.sh deploy --tags docker_swarm` |
| [Docker Swarm Leave](docker-swarm/README.md) | Make selected nodes leave their current Swarm. | `./scripts/run-ansible.sh deploy --tags docker_swarm_leave` |
| [Docker Swarm iptables](docker-swarm-iptables/README.md) | Open Swarm and published service ports. | `./scripts/run-ansible.sh deploy --tags docker_swarm_iptables` |
| [Offline Bundle Build](offline-bundle/README.md) | Build a portable offline Ansible bundle on an online machine. | `./scripts/build-offline-bundle.sh` |
| [Offline Control Prepare](offline-control/README.md) | Load the packaged runtime image on the offline control machine. | `./scripts/prepare-offline-control.sh` |
