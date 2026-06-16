# Network

This task writes a static Netplan configuration and applies it immediately.

Use this task carefully. Changing an IP address can interrupt the current SSH
session.

## Key Variables

```env
ANSIBLE_NETWORK_MANAGE=true
ANSIBLE_NETWORK_INTERFACE=ens34
ANSIBLE_NETWORK_IPV4_ADDRESS=<target-ip>
ANSIBLE_NETWORK_IPV4_PREFIX_LENGTH=24
ANSIBLE_NETWORK_IPV4_GATEWAY=<gateway-ip>
ANSIBLE_NETWORK_DNS_SERVERS="[<dns-ip-1>, <dns-ip-2>]"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags network --limit <target-host-or-ip>
```

## Safety Notes

- Test one host at a time.
- Make sure the target host is reachable at the new address.
- Update `.env` inventory host lists after changing IP addresses.
