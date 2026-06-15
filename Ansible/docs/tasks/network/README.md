# Network

This task writes a static Netplan configuration and applies it immediately.

Use this task carefully. Changing an IP address can interrupt the current SSH
session.

## Key Variables

```env
ANSIBLE_NETWORK_MANAGE=true
ANSIBLE_NETWORK_INTERFACE=ens34
ANSIBLE_NETWORK_IPV4_ADDRESS=172.16.3.21
ANSIBLE_NETWORK_IPV4_PREFIX_LENGTH=24
ANSIBLE_NETWORK_IPV4_GATEWAY=172.16.3.1
ANSIBLE_NETWORK_DNS_SERVERS="[172.16.3.200, 172.16.3.201]"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags network --limit 172.16.3.21
```

## Safety Notes

- Test one host at a time.
- Make sure the target host is reachable at the new address.
- Update `.env` inventory host lists after changing IP addresses.

