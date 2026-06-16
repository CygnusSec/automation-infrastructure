# DNS And Time Services

This task deploys DNS and time server containers on `dns_time_servers`.

## What It Does

- validates Docker is available on the targets
- renders BIND configuration and zone files
- renders Chrony configuration
- loads Docker images from tar files when needed
- runs BIND and Chrony containers with host networking

## Key Variables

```env
ANSIBLE_DNS_TIME_SERVICES_ENABLED=true
ANSIBLE_DNS_TIME_SERVICES_TARGET_GROUP=dns_time_servers
# ANSIBLE_DNS_TIME_SERVER_HOSTS="<dns-time-ip-1>,<dns-time-ip-2>"
ANSIBLE_DNS_TIME_SERVICES_LOAD_IMAGES=true
ANSIBLE_DNS_TIME_SERVICES_BASE_DIR=/opt/ansible-dns-time
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags dns_time_services
```

## Related Runbooks

- [DNS Server](../dns-server/README.md)
- [Time Server](../time-server/README.md)
