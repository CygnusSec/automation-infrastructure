# iptables

Configures common iptables ACCEPT rules for loopback traffic, established
connections, SSH from a configured whitelist, DNS/time, Zabbix, and optional
non-Swarm host service exceptions.

Set values in `env.d/20-base.env`:

```env
ANSIBLE_IPTABLES_ENABLED=true
ANSIBLE_IPTABLES_TARGET_GROUP=iptables_targets
ANSIBLE_IPTABLES_RESET_ENABLED=true
ANSIBLE_IPTABLES_RESET_CHAINS="[INPUT, OUTPUT]"
ANSIBLE_IPTABLES_SSH_WHITELIST_IPS="172.16.3.21,172.16.3.22"
ANSIBLE_IPTABLES_SSH_PORT=22
ANSIBLE_IPTABLES_SERVICE_ALLOWED_SOURCE_IPS="[]"
ANSIBLE_IPTABLES_EXTERNAL_SERVICE_RULES="[]"
ANSIBLE_IPTABLES_INBOUND_SERVICE_RULES="[{name: database_in, target_ips: [172.16.4.11, 172.16.4.12], source_ips: [172.16.3.21, 172.16.3.22], ports: [3306]}]"
ANSIBLE_IPTABLES_IP_PORT_RULES="[{ip: 172.16.5.100, ports: [80, 443]}, {ip: 172.16.5.102, ports: [8080]}, {ip: 172.16.5.103, ports: []}]"
ANSIBLE_IPTABLES_ZABBIX_SERVER_IPS="[172.16.5.57]"
ANSIBLE_IPTABLES_ZABBIX_AGENT_PORT=10050
ANSIBLE_IPTABLES_ZABBIX_SERVER_PORT=10051
ANSIBLE_IPTABLES_DNS_TIME_SERVER_IPS="[172.16.3.200, 172.16.3.201]"
ANSIBLE_IPTABLES_DNS_TIME_CLIENT_SOURCES="[]"
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

Run only primary allow rules (`lo`, established traffic, SSH, DNS/time, and
non-Swarm service exceptions such as `443`):

```bash
./scripts/run-ansible.sh deploy --tags iptables_primary
```

Run only Zabbix allow rules:

```bash
./scripts/run-ansible.sh deploy --tags iptables_zabbix
```

The singular alias also works:

```bash
./scripts/run-ansible.sh deploy --tags iptable
```

Block `INPUT` and `OUTPUT` as a separate task after allow rules are in place:

```bash
./scripts/run-ansible.sh deploy --tags iptables_block
```

Set `ANSIBLE_IPTABLES_BLOCK_ENABLED=true` in `env.d/20-base.env` before running
the block task. The runner loads `env.d/20-base.env` for this tag.

The role checks each rule with `iptables -C` before adding it with
`iptables -I`, so reruns do not duplicate rules and allow rules stay before
Docker-managed DROP rules.

At the end of the run, the role reinserts priority rules so loopback stays
first, followed by DNS/time rules, then SSH rules.

By default the role first sets `INPUT` and `OUTPUT` policy to `ACCEPT`, flushes
old rules from those chains, then applies the configured rules. Set
`ANSIBLE_IPTABLES_RESET_ENABLED=false` if you need additive behavior.

Docker Swarm peer rules, published service source IPs, and Swarm container
external service rules remain in the separate `docker_swarm_iptables` task.

On agent hosts, Zabbix rules allow the server to poll agents on `10050/tcp`
and allow active agents to connect back to the server on `10051/tcp`. On the
Zabbix server host, the role only opens polling traffic to agent hosts on
`10050/tcp`; it does not add active-agent `10051/tcp` rules to itself.

DNS/time rules allow clients to reach DNS servers on `53/tcp` and `53/udp`,
and time servers on `123/udp`. They also allow local hosts to query the
configured DNS/time server IPs.

`ANSIBLE_IPTABLES_IP_PORT_RULES` allows per-IP port lists. Entries with
`ports: []` are skipped until ports are filled in `env.d/20-base.env`.

`ANSIBLE_IPTABLES_INBOUND_SERVICE_RULES` applies only on hosts whose IP is in
`target_ips`. It allows `source_ips` to connect to the configured `ports` and
adds the matching response `OUTPUT` rules.
