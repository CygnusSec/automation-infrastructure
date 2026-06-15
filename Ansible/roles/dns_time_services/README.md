# dns_time_services

Deploys Dockerized DNS and time services on the `dns_time_servers` inventory
group.

## Services

- DNS: BIND 9 container, default image `local/bind9:offline`
- Time: Chrony container, default image `local/chrony:offline`

## Main Commands

Deploy both services:

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags dns_time_services
```

Deploy only DNS:

```bash
./scripts/run-ansible.sh deploy --tags dns_server
```

Deploy only time server:

```bash
./scripts/run-ansible.sh deploy --tags time_server
```

## Task Runbooks

- [DNS And Time Services](../../docs/tasks/dns-time-services/README.md)
- [DNS Server](../../docs/tasks/dns-server/README.md)
- [Time Server](../../docs/tasks/time-server/README.md)

