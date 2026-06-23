# iptables

This task configures common iptables ACCEPT rules on the configured target
group.

Run order for applying allow rules and final DROP policies:
[RUN_ORDER.md](RUN_ORDER.md)

## What It Does

- allows loopback input and output traffic
- allows established and related input connections
- allows established output connections
- allows new and established SSH input from `ANSIBLE_IPTABLES_SSH_WHITELIST_IPS`
- allows established SSH output back to `ANSIBLE_IPTABLES_SSH_WHITELIST_IPS`
- allows optional non-Swarm external service IP/port lists through `OUTPUT`,
  plus response traffic through `INPUT`
- allows custom per-IP port lists from `ANSIBLE_IPTABLES_IP_PORT_RULES`
- allows Zabbix server IPs to poll agents on `10050/tcp`
- allows active Zabbix agents to connect to the server on `10051/tcp`
- on the Zabbix server host, opens only polling traffic to agents on
  `10050/tcp`
- allows DNS client/server traffic on `53/tcp` and `53/udp`
- allows time/NTP client/server traffic on `123/udp`
- optionally blocks `INPUT` and `OUTPUT` as a separate `iptables_block` task

The `iptables` task does not set default DROP policies. The separate
`iptables_block` task sets selected chain policies to `DROP`.

## Key Variables

Set target hosts in `env.d/10-inventory.env`:

```env
ANSIBLE_IPTABLES_HOSTS="172.16.3.21,172.16.3.22"
```

Set role options in `env.d/20-base.env`:

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

`ANSIBLE_IPTABLES_SSH_WHITELIST_IPS` is a comma-separated list of IPv4
addresses or CIDRs.

`ANSIBLE_IPTABLES_RESET_ENABLED=true` makes the role set `INPUT` and `OUTPUT`
policy to `ACCEPT`, flush old rules from `ANSIBLE_IPTABLES_RESET_CHAINS`, then
apply the new rules.

`ANSIBLE_IPTABLES_SERVICE_ALLOWED_SOURCE_IPS` must stay `[]` in DROP mode. The
role rejects non-empty values because that legacy setting would create broad
host-level allow rules. Use `ANSIBLE_IPTABLES_INBOUND_SERVICE_RULES`,
`ANSIBLE_IPTABLES_EXTERNAL_SERVICE_RULES`, or `ANSIBLE_IPTABLES_IP_PORT_RULES`
so each whitelist also names the allowed port.

`ANSIBLE_IPTABLES_EXTERNAL_SERVICE_RULES` is a YAML list of service definitions.
Each item supports `name`, `ips`, `ports`, and optional `protocol` (`tcp` by
default). Use it only for non-Swarm host traffic. Swarm container external
service traffic should be set in `ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES`
so it is written to `DOCKER-USER`.

`ANSIBLE_IPTABLES_INBOUND_SERVICE_RULES` is a YAML list for services hosted on
the current target. A rule applies only when the host IP is in `target_ips`,
then allows `source_ips` to connect to `ports` and allows matching response
traffic back out.

`ANSIBLE_IPTABLES_IP_PORT_RULES` is a YAML list of per-IP allow rules. Each item
supports `ip`, `ports`, and optional `protocol` (`tcp` by default). Entries with
`ports: []` are skipped.

The role checks each rule with `iptables -C` before inserting it with
`iptables -I`, so allow rules stay before Docker-managed DROP rules.
It finishes by reinserting priority rules so loopback stays first, followed by
DNS/time rules, then SSH rules.

`ANSIBLE_IPTABLES_ZABBIX_SERVER_IPS` is a YAML list of Zabbix server IPv4
addresses or CIDRs. The role opens passive agent polling on
`ANSIBLE_IPTABLES_ZABBIX_AGENT_PORT` and active agent outbound traffic to
`ANSIBLE_IPTABLES_ZABBIX_SERVER_PORT`.

`ANSIBLE_IPTABLES_DNS_TIME_SERVER_IPS` is a YAML list of DNS/time server IPv4
addresses or CIDRs. `ANSIBLE_IPTABLES_DNS_TIME_CLIENT_SOURCES` is a YAML list of
client source IPv4 addresses or CIDRs allowed to query local DNS/time services.
When `ANSIBLE_IPTABLES_DNS_TIME_CLIENT_SOURCES=[]`, DNS/time server hosts allow
all hosts in `ANSIBLE_IPTABLES_TARGET_GROUP` to connect to `53/tcp`, `53/udp`,
and `123/udp`.

`ANSIBLE_IPTABLES_BLOCK_CHAINS` supports only `INPUT`, `FORWARD`, and `OUTPUT`.

When `ANSIBLE_IPTABLES_MANAGE_IPSETS=true`, common rules use `ipset` groups
instead of one rule per IP. The role saves those sets to
`ANSIBLE_IPTABLES_IPSET_SAVE_PATH` when persistence is enabled. The role also
writes `iptables-save` output to `ANSIBLE_IPTABLES_SAVE_PATH` when
`ANSIBLE_IPTABLES_PERSIST=true`, so `netfilter-persistent` can restore the
filter rules after reboot.

## Command

Add allow rules first:

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags iptables
```

Save the current ipset and iptables state only:

```bash
./scripts/run-ansible.sh deploy --tags iptables_save
```

The singular alias also works:

```bash
./scripts/run-ansible.sh deploy --tags iptable
```

Then block `INPUT` and `OUTPUT` separately:

```bash
./scripts/run-ansible.sh deploy --tags iptables_block
```

Set `ANSIBLE_IPTABLES_BLOCK_ENABLED=true` in `env.d/20-base.env` before running
the block task. The runner loads `env.d/20-base.env` for this tag.
