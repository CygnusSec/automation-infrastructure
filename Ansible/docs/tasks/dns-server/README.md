# DNS Server

This task deploys only the BIND DNS container.

## What It Does

- renders `named.conf`
- renders `named.conf.options`
- renders zone files
- loads `local/bind9:offline` from `repo/docker-images/bind9.tar` when needed
- runs the DNS container on host networking

## Key Variables

```env
ANSIBLE_DNS_SERVER_ENABLED=true
ANSIBLE_DNS_SERVER_IMAGE=local/bind9:offline
ANSIBLE_DNS_SERVER_IMAGE_TAR=./repo/docker-images/bind9.tar
ANSIBLE_DNS_SERVER_ALLOW_QUERY="[<allowed-cidr>]"
ANSIBLE_DNS_SERVER_FORWARDERS="[]"
ANSIBLE_DNS_SERVER_ZONE_SERIAL=1
ANSIBLE_DNS_SERVER_ZONES="[{name: example.local, records: [{name: api, type: A, value: <app-ip>}, {name: file, type: A, value: <file-ip>}, {name: cache, type: A, value: <cache-ip>}]}]"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags dns_server
```

## Verification

From a host that can reach the DNS server:

```bash
dig @<dns-server-ip> api.example.local
dig @<dns-server-ip> file.example.local
dig @<dns-server-ip> cache.example.local
```
