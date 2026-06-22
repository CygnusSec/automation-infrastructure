# iptables

Configures common iptables ACCEPT rules for loopback traffic, established
connections, SSH from a configured whitelist, service source IPs, and outbound
external service IP/port lists.

Set values in `env.d/20-base.env`:

```env
ANSIBLE_IPTABLES_ENABLED=true
ANSIBLE_IPTABLES_TARGET_GROUP=iptables_targets
ANSIBLE_IPTABLES_SSH_WHITELIST_IPS="172.16.3.21,172.16.3.22"
ANSIBLE_IPTABLES_SSH_PORT=22
ANSIBLE_IPTABLES_SERVICE_ALLOWED_SOURCE_IPS="[172.16.3.97, 172.16.3.98]"
ANSIBLE_IPTABLES_EXTERNAL_SERVICE_RULES="[{name: database, ips: [172.16.4.2], ports: [3306]}]"
ANSIBLE_IPTABLES_IP_PORT_RULES="[{ip: 172.16.5.100, ports: [80, 443]}, {ip: 172.16.5.102, ports: [8080]}, {ip: 172.16.5.103, ports: []}]"
ANSIBLE_IPTABLES_ZABBIX_SERVER_IPS="[172.16.5.57]"
ANSIBLE_IPTABLES_ZABBIX_AGENT_PORT=10050
ANSIBLE_IPTABLES_ZABBIX_SERVER_PORT=10051
ANSIBLE_IPTABLES_DNS_TIME_SERVER_IPS="[172.16.3.200, 172.16.3.201]"
ANSIBLE_IPTABLES_DNS_TIME_CLIENT_SOURCES="[172.16.0.0/16]"
ANSIBLE_IPTABLES_DNS_PORT=53
ANSIBLE_IPTABLES_TIME_PORT=123
ANSIBLE_IPTABLES_BLOCK_ENABLED=false
ANSIBLE_IPTABLES_BLOCK_CHAINS="[INPUT, OUTPUT]"
```

Set the target hosts in `env.d/10-inventory.env`:

```env
ANSIBLE_IPTABLES_HOSTS="172.16.3.21,172.16.3.22"
```

Run only this role:

```bash
./scripts/run-ansible.sh deploy --tags iptables
```

Block `INPUT` and `OUTPUT` as a separate task after allow rules are in place:

```bash
./scripts/run-ansible.sh deploy --tags iptables_block
```

Set `ANSIBLE_IPTABLES_BLOCK_ENABLED=true` in `env.d/20-base.env` before running
the block task. The runner loads `env.d/20-base.env` for this tag.

The role checks each rule with `iptables -C` before adding it with
`iptables -A`, so reruns do not duplicate rules.

Service rules are added to `INPUT` and `OUTPUT` only. Docker Swarm peer rules
remain in the separate `docker_swarm_iptables` task.

Zabbix rules allow the server to poll agents on `10050/tcp` and allow active
agents to connect back to the server on `10051/tcp`.

DNS/time rules allow clients to reach DNS servers on `53/tcp` and `53/udp`,
and time servers on `123/udp`. They also allow local hosts to query the
configured DNS/time server IPs.

`ANSIBLE_IPTABLES_IP_PORT_RULES` allows per-IP port lists. Entries with
`ports: []` are skipped until ports are filled in `env.d/20-base.env`.
