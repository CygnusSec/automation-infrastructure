# iptables Run Order

Run iptables tasks in this order when applying `INPUT`, `FORWARD`, and
`OUTPUT` default `DROP` policies.

## 1. Check Env Files

Review these files before running:

```bash
env.d/10-inventory.env
env.d/20-base.env
env.d/60-docker-swarm.env
```

Important values:

- `ANSIBLE_IPTABLES_HOSTS`
- `ANSIBLE_IPTABLES_SSH_WHITELIST_IPS`
- `ANSIBLE_IPTABLES_DNS_TIME_SERVER_IPS`
- `ANSIBLE_IPTABLES_ZABBIX_SERVER_IPS`
- `ANSIBLE_IPTABLES_EXTERNAL_SERVICE_RULES`
- `ANSIBLE_IPTABLES_INBOUND_SERVICE_RULES`
- `ANSIBLE_DOCKER_SWARM_SERVICE_ALLOWED_SOURCE_IPS`
- `ANSIBLE_DOCKER_SWARM_EXTERNAL_SERVICE_RULES`
- `ANSIBLE_IPTABLES_BLOCK_ENABLED`
- `ANSIBLE_IPTABLES_BLOCK_CHAINS`

Keep `ANSIBLE_IPTABLES_SERVICE_ALLOWED_SOURCE_IPS="[]"` in DROP mode. Use
explicit rules with ports instead.

## 2. Install Prerequisite Packages

Install iptables/ipset persistence packages first. This is required so rules
survive reboot.

```bash
./scripts/run-ansible.sh deploy --tags prerequisite
```

Expected packages include:

- `iptables-persistent`
- `netfilter-persistent`
- `ipset`
- `ipset-persistent`

## 3. Apply Common Allow Rules

Apply host-level allow rules before enabling default DROP policies.

```bash
./scripts/run-ansible.sh deploy --tags iptables
```

This applies:

- loopback INPUT/OUTPUT
- established and related traffic
- SSH whitelist
- DNS/time
- management HTTPS rules
- inbound service rules
- outbound external service rules
- Zabbix rules
- common ipsets
- common iptables/ipset save tasks

## 4. Apply Docker Swarm iptables Rules

Run this only for Swarm nodes.

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables
```

This applies:

- Swarm node communication
- manager join traffic
- encrypted overlay ESP when enabled
- `DOCKER-USER` allow connect in
- `DOCKER-USER` allow connect out
- logger rules

If debugging, the sub-task order is:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_ipsets
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_nodes
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_in
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_out
```

## 5. Save Rules Explicitly

Save is explicit. Run these tags only when you need to save the current runtime
state manually.

```bash
./scripts/run-ansible.sh deploy --tags iptables_save
```

Saved files:

```text
/etc/iptables/ipsets
/etc/iptables/rules.v4
```

## 6. Review Generated Output

Compare generated output before enabling default DROP policies.

```bash
ls output/iptables-rules
ls output/docker-swarm-iptables-rules
ls output/all-iptables-rules
sed -n '1,180p' output/iptables-output-audit.txt
```

The combined output for each host should end with:

```bash
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables-save > /etc/iptables/rules.v4
```

## 7. Enable Default DROP Policies

Run this only after allow rules are confirmed.

```bash
./scripts/run-ansible.sh deploy --tags iptables_block
```

Required env:

```env
ANSIBLE_IPTABLES_BLOCK_ENABLED=true
ANSIBLE_IPTABLES_BLOCK_CHAINS="[INPUT, FORWARD, OUTPUT]"
```

This sets:

```bash
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
```

and saves the final state with `iptables-save`.

## 8. Verify After Running

On a target host:

```bash
iptables -S INPUT
iptables -S FORWARD
iptables -S OUTPUT
iptables -S DOCKER-USER
ipset list
systemctl status netfilter-persistent
```

Check that:

- `INPUT`, `FORWARD`, and `OUTPUT` policies are `DROP`
- allow rules are above DROP behavior
- `DOCKER-USER` removes Docker's default `RETURN` before final `DROP`
- ipsets are restored before iptables rules after reboot
- `/etc/iptables/ipsets` and `/etc/iptables/rules.v4` exist
