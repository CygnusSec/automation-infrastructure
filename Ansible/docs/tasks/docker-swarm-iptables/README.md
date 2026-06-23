# Docker Swarm iptables

This task configures iptables rules for Swarm manager join traffic, node
discovery, and overlay networking. It builds peer IPs from the configured
`swarm_managers` and `swarm_workers` inventory groups and skips each node's own
IP, matching the behavior of the legacy `allow_swarm` shell function.

It is separated from the main Swarm task. Running `--tags docker_swarm` does not
run iptables management.

## Key Variables

```env
ANSIBLE_DOCKER_SWARM_MANAGE_IPTABLES=true
ANSIBLE_DOCKER_SWARM_MANAGE_ENCRYPTED_OVERLAY_ESP=true
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

Service source IPs for published Swarm services are handled in `DOCKER-USER`:

```bash
iptables -A DOCKER-USER -s <source-ip> -i <host-interface> -o docker_gwbridge -p tcp -m multiport --dports <ports> -j ACCEPT
iptables -A DOCKER-USER -d <source-ip> -o <host-interface> -i docker_gwbridge -p tcp -m multiport --sports <ports> -j ACCEPT
```

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

External service IP/port lists for Swarm containers are also handled in
`DOCKER-USER`:

```bash
iptables -A DOCKER-USER -s <external-ip> -i <host-interface> -o docker_gwbridge -p tcp -m multiport --sports <ports> -j ACCEPT
iptables -A DOCKER-USER -d <external-ip> -o <host-interface> -i docker_gwbridge -p tcp -m multiport --dports <ports> -j ACCEPT
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables
```

Sub-task tags:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_nodes
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_in
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_out
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_docker_user_drop
```

## Opened Traffic

- worker/client traffic to managers on `2377/tcp`
- manager/server traffic from nodes on `2377/tcp`
- bidirectional node discovery on `7946/tcp`
- bidirectional node discovery on `7946/udp`
- bidirectional overlay networking on `4789/udp`
- bidirectional protocol `esp` when encrypted overlay support is enabled
- logger nodes with `node_tag=logger` accept `514/tcp` and `514/udp` from all
  Swarm node IPs
- published service source IPs through `DOCKER-USER` when
  `ANSIBLE_DOCKER_SWARM_SERVICE_ALLOWED_SOURCE_IPS` is set
- Swarm container access to external services through `DOCKER-USER` when
  `ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES` is set
- final `DOCKER-USER` drop rule when
  `ANSIBLE_DOCKER_SWARM_DOCKER_USER_DROP_ENABLED=true`
