# Docker Swarm iptables

This task configures iptables rules for Swarm manager join traffic, node
discovery, and overlay networking. It uses `ipset` to group Swarm nodes,
manager nodes, service clients, and external service backends so iptables does
not need one rule per IP.

It is separated from the main Swarm task. Running `--tags docker_swarm` does not
run iptables management.

## Key Variables

```env
ANSIBLE_DOCKER_SWARM_MANAGE_IPTABLES=true
ANSIBLE_DOCKER_SWARM_MANAGE_ENCRYPTED_OVERLAY_ESP=true
ANSIBLE_DOCKER_SWARM_MANAGE_IPSETS=true
ANSIBLE_DOCKER_SWARM_IPSET_PERSIST=true
ANSIBLE_DOCKER_SWARM_IPSET_SAVE_PATH=/etc/iptables/ipsets
ANSIBLE_DOCKER_SWARM_IPTABLES_PERSIST=true
ANSIBLE_DOCKER_SWARM_IPTABLES_SAVE_PATH=/etc/iptables/rules.v4
ANSIBLE_DOCKER_SWARM_IPSET_MANAGERS_NAME=swarm_managers
ANSIBLE_DOCKER_SWARM_IPSET_NODES_NAME=swarm_nodes
ANSIBLE_DOCKER_SWARM_IPSET_SERVICE_CLIENTS_NAME=app_clients
ANSIBLE_DOCKER_SWARM_IPSET_LOGGER_NAME=syslog_nodes
ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_IPSET_NAMES="{database: mysql_nodes, storage: minio_nodes}"
ANSIBLE_DOCKER_SWARM_SERVICE_ALLOWED_SOURCE_IPS="[172.16.3.98, 172.16.3.99]"
ANSIBLE_DOCKER_SWARM_SERVICE_HOST_INTERFACE=ens18
ANSIBLE_DOCKER_SWARM_SERVICE_BRIDGE_INTERFACE=docker_gwbridge
ANSIBLE_DOCKER_SWARM_SERVICE_PORTS="[80]"
ANSIBLE_DOCKER_SWARM_SERVICE_PORTS_BY_HOST="{172.16.3.21: [80, 6380], 172.16.3.24: [1070]}"
ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES="[{name: database, ips: [172.16.4.11, 172.16.4.12], ports: [3306]}]"
ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES_BY_HOST="{172.16.3.24: [{name: storage, ips: [172.16.4.13, 172.16.4.14], ports: [9000]}]}"
ANSIBLE_DOCKER_SWARM_LOGGER_NODE_TAG=logger
ANSIBLE_DOCKER_SWARM_LOGGER_PORT=514
ANSIBLE_DOCKER_SWARM_LOGGER_PROTOCOLS="[tcp, udp]"
```

Managed ipsets:

- `swarm_managers`: manager node IPs
- `swarm_nodes`: all manager and worker node IPs
- `app_clients`: IPs in `ANSIBLE_DOCKER_SWARM_SERVICE_ALLOWED_SOURCE_IPS`
- `mysql_nodes`: `database` external service IPs by default
- `minio_nodes`: `storage` external service IPs by default
- `syslog_nodes`: logger node IPs

Service source IPs for published Swarm services are handled in `DOCKER-USER`
with `app_clients`:

```bash
iptables -A DOCKER-USER -m set --match-set app_clients src -i <host-interface> -o docker_gwbridge -p tcp -m multiport --dports <ports> -j ACCEPT
```

The role inserts `ESTABLISHED,RELATED` rules, so it does not write separate
reverse `--sports` rules.

`ANSIBLE_DOCKER_SWARM_SERVICE_PORTS_BY_HOST` overrides
`ANSIBLE_DOCKER_SWARM_SERVICE_PORTS` for matching node IPs.
`ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES_BY_HOST` overrides
`ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES` for matching node IPs.
Nodes with `node_tag=logger` allow every Swarm node IP to connect to the
configured logger port, default `514/tcp` and `514/udp`.
Every Swarm node also gets `DOCKER-USER` rules allowing Swarm container traffic
to logger node IPs on the configured logger port.
When `ANSIBLE_DOCKER_SWARM_DOCKER_USER_DROP_ENABLED=true`, the role appends
`iptables -A DOCKER-USER -j DROP` after allow rules and removes Docker's
default `iptables -D DOCKER-USER -j RETURN` first.

When persistence is enabled, the task saves ipsets to `/etc/iptables/ipsets`
and the final iptables state to `/etc/iptables/rules.v4`, so
`netfilter-persistent` can restore both after reboot.

External service IP/port lists for Swarm containers are also handled in
`DOCKER-USER`:

```bash
iptables -A DOCKER-USER -i docker_gwbridge -o <host-interface> -m set --match-set mysql_nodes dst -p tcp -m multiport --dports 3306 -j ACCEPT
iptables -A DOCKER-USER -i docker_gwbridge -o <host-interface> -m set --match-set minio_nodes dst -p tcp -m multiport --dports 9000 -j ACCEPT
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables
```

Sub-task tags:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_nodes
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_ipsets
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_in
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_out
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_docker_user_drop
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_save
```

## Opened Traffic

- worker/client traffic to `swarm_managers` on `2377/tcp`
- manager/server traffic from `swarm_nodes` on `2377/tcp`
- node discovery with `swarm_nodes` on `7946/tcp`
- node discovery with `swarm_nodes` on `7946/udp`
- overlay networking with `swarm_nodes` on `4789/udp`
- IP protocol `esp` with `swarm_nodes` when encrypted overlay support is enabled
- logger nodes with `node_tag=logger` accept `514/tcp` and `514/udp` from all
  Swarm node IPs
- published service source IPs through `DOCKER-USER` when
  `ANSIBLE_DOCKER_SWARM_SERVICE_ALLOWED_SOURCE_IPS` is set
- Swarm container access to external services through `DOCKER-USER` when
  `ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES` is set
- final `DOCKER-USER` drop rule when
  `ANSIBLE_DOCKER_SWARM_DOCKER_USER_DROP_ENABLED=true`
