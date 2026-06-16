# network

Writes a static Netplan configuration for Ubuntu and applies it immediately.

Example:

```yaml
network_manage: true
network_interface: ens18
network_ipv4_address: <target-ip>
network_ipv4_prefix_length: 24
network_ipv4_gateway: <gateway-ip>
network_dns_servers:
  - <dns-ip-1>
  - <dns-ip-2>
```

Use with care because applying a new IP can interrupt the current Ansible session.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags network --limit <target-host-or-ip>
```

When `/etc/netplan/50-cloud-init.yaml` exists, this role backs it up to
`/etc/netplan/50-cloud-init.yaml.ansible.bak` and removes the original file so
the new static IP replaces the old cloud-init network config instead of being
added alongside it.

To avoid the play appearing stuck on the old SSH session, the role triggers
`netplan apply` in the background and then waits from the control node until
SSH is reachable on the new IP.

## Task Runbook

See [Network](../../docs/tasks/network/README.md).
