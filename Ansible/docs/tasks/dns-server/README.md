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
ANSIBLE_DNS_SERVER_ALLOW_QUERY="[172.16.0.0/16]"
ANSIBLE_DNS_SERVER_FORWARDERS="[]"
ANSIBLE_DNS_SERVER_ZONE_SERIAL=1
ANSIBLE_DNS_SERVER_ZONES="[{name: bcy.gov.vn, records: [{name: api, type: A, value: 172.16.3.100}, {name: file, type: A, value: 172.16.3.100}, {name: cache, type: A, value: 172.16.3.101}]}]"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags dns_server
```

## Verification

From a host that can reach the DNS server:

```bash
dig @172.16.3.200 api.bcy.gov.vn
dig @172.16.3.200 file.bcy.gov.vn
dig @172.16.3.200 cache.bcy.gov.vn
```

