# iptables

This task configures common iptables ACCEPT rules on the configured target
group.

## What It Does

- allows loopback input and output traffic
- allows established and related input connections
- allows established output connections
- allows new and established SSH input from `ANSIBLE_IPTABLES_SSH_WHITELIST_IPS`
- allows established SSH output back to `ANSIBLE_IPTABLES_SSH_WHITELIST_IPS`
- allows configured source IPs to reach services on the host through `INPUT`
  and allows response traffic through `OUTPUT`
- allows outbound traffic from the host to configured external service IP and
  port lists through `OUTPUT`, plus response traffic through `INPUT`
- allows custom per-IP port lists from `ANSIBLE_IPTABLES_IP_PORT_RULES`
- allows Zabbix server IPs to poll agents on `10050/tcp`
- allows active Zabbix agents to connect to the server on `10051/tcp`
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

`ANSIBLE_IPTABLES_SSH_WHITELIST_IPS` is a comma-separated list of IPv4
addresses or CIDRs.

`ANSIBLE_IPTABLES_SERVICE_ALLOWED_SOURCE_IPS` is a YAML list of IPv4 addresses
or CIDRs that may connect to services on the target hosts.

`ANSIBLE_IPTABLES_EXTERNAL_SERVICE_RULES` is a YAML list of service definitions.
Each item supports `name`, `ips`, `ports`, and optional `protocol` (`tcp` by
default). The role writes these as `INPUT` and `OUTPUT` rules, not Docker
`DOCKER-USER` rules.

`ANSIBLE_IPTABLES_IP_PORT_RULES` is a YAML list of per-IP allow rules. Each item
supports `ip`, `ports`, and optional `protocol` (`tcp` by default). Entries with
`ports: []` are skipped.

`ANSIBLE_IPTABLES_ZABBIX_SERVER_IPS` is a YAML list of Zabbix server IPv4
addresses or CIDRs. The role opens passive agent polling on
`ANSIBLE_IPTABLES_ZABBIX_AGENT_PORT` and active agent outbound traffic to
`ANSIBLE_IPTABLES_ZABBIX_SERVER_PORT`.

`ANSIBLE_IPTABLES_DNS_TIME_SERVER_IPS` is a YAML list of DNS/time server IPv4
addresses or CIDRs. `ANSIBLE_IPTABLES_DNS_TIME_CLIENT_SOURCES` is a YAML list of
client source IPv4 addresses or CIDRs allowed to query local DNS/time services.

`ANSIBLE_IPTABLES_BLOCK_CHAINS` supports only `INPUT` and `OUTPUT`.

## Command

Add allow rules first:

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags iptables
```

Then block `INPUT` and `OUTPUT` separately:

```bash
./scripts/run-ansible.sh deploy --tags iptables_block
```

Set `ANSIBLE_IPTABLES_BLOCK_ENABLED=true` in `env.d/20-base.env` before running
the block task. The runner loads `env.d/20-base.env` for this tag.
