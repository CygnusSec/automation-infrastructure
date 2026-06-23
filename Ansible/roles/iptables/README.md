# iptables

Configures common iptables ACCEPT rules for loopback traffic, established
connections, SSH from a configured whitelist, DNS/time, Zabbix, and optional
non-Swarm host service rules with explicit source IPs and ports.

Set values in `env.d/20-base.env`:

```env
ANSIBLE_IPTABLES_ENABLED=true
ANSIBLE_IPTABLES_TARGET_GROUP=iptables_targets
ANSIBLE_IPTABLES_RESET_ENABLED=true
ANSIBLE_IPTABLES_RESET_CHAINS="[INPUT, OUTPUT]"
ANSIBLE_IPTABLES_MANAGE_IPSETS=true
ANSIBLE_IPTABLES_IPSET_PERSIST=true
ANSIBLE_IPTABLES_IPSET_SAVE_PATH=/etc/iptables/ipsets
ANSIBLE_IPTABLES_PERSIST=true
ANSIBLE_IPTABLES_SAVE_PATH=/etc/iptables/rules.v4
ANSIBLE_IPTABLES_IPSET_PREFIX=common
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
ANSIBLE_IPTABLES_BLOCK_CHAINS="[INPUT, FORWARD, OUTPUT]"
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
non-Swarm service rules such as `443`):

```bash
./scripts/run-ansible.sh deploy --tags iptables_primary
```

Run only Zabbix allow rules:

```bash
./scripts/run-ansible.sh deploy --tags iptables_zabbix
```

Save the current ipset and iptables state only:

```bash
./scripts/run-ansible.sh deploy --tags iptables_save
```

The singular alias also works:

```bash
./scripts/run-ansible.sh deploy --tags iptable
```

Block `INPUT`, `FORWARD`, and `OUTPUT` as a separate task after allow rules are
in place:

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

Keep `ANSIBLE_IPTABLES_SERVICE_ALLOWED_SOURCE_IPS=[]` in DROP mode. Non-empty
values are rejected because that legacy variable would create broad host-level
allow rules without explicit ports.

On agent hosts, Zabbix rules allow the server to poll agents on `10050/tcp`
and allow active agents to connect back to the server on `10051/tcp`. On the
Zabbix server host, the role only opens polling traffic to agent hosts on
`10050/tcp`; it does not add active-agent `10051/tcp` rules to itself.

DNS/time rules allow clients to reach DNS servers on `53/tcp` and `53/udp`,
and time servers on `123/udp`. On DNS/time server hosts, `OUTPUT` uses
`--sport 53` and `--sport 123` back to `common_dns_time_clients`. On other
hosts, `OUTPUT` uses `--dport 53` and `--dport 123` to
`common_dns_time_servers`.
When `ANSIBLE_IPTABLES_DNS_TIME_CLIENT_SOURCES=[]`, DNS/time server hosts allow
all hosts in `ANSIBLE_IPTABLES_TARGET_GROUP` to connect to those DNS/time
ports. Set this variable to a YAML list of source IPs/CIDRs to restrict access.

`ANSIBLE_IPTABLES_IP_PORT_RULES` allows per-IP port lists. Entries with
`ports: []` are skipped until ports are filled in `env.d/20-base.env`.

`ANSIBLE_IPTABLES_INBOUND_SERVICE_RULES` applies only on hosts whose IP is in
`target_ips`. It allows `source_ips` to connect to the configured `ports` and
adds the matching response `OUTPUT` rules.

`ANSIBLE_IPTABLES_EXTERNAL_SERVICE_RULES` is client-side on hosts outside the
service IP list. If the current host IP is listed in a rule's `ips`, that host
is treated as the service server and gets `INPUT --dport` plus `OUTPUT --sport`
rules for the configured ports.

When `ANSIBLE_IPTABLES_MANAGE_IPSETS=true`, the role creates common ipsets for
SSH sources, DNS/time servers, Zabbix servers/agents, and configured service
groups, then writes iptables rules with `-m set --match-set`. The role saves the
sets to `/etc/iptables/ipsets` when `ANSIBLE_IPTABLES_IPSET_PERSIST=true`.

When `ANSIBLE_IPTABLES_PERSIST=true`, the role also runs `iptables-save` to
write `/etc/iptables/rules.v4`. With `ipset-persistent`,
`iptables-persistent`, and `netfilter-persistent` installed, the saved ipsets
and iptables rules are restored after reboot.
The save task checks that netfilter-persistent has `10-ipset` and
`15-ip4tables`, so ipsets are restored before iptables rules that reference
them.
