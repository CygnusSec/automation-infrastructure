# ntp_client

Configures target hosts to use internal NTP servers through
`systemd-timesyncd`.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags ntp_client
```

## Key Variables

```env
ANSIBLE_NTP_CLIENT_ENABLED=true
ANSIBLE_NTP_CLIENT_TARGET_GROUP=all_targets:!dns_time_servers
ANSIBLE_NTP_CLIENT_SERVERS="[172.16.3.200, 172.16.3.201]"
ANSIBLE_NTP_CLIENT_FALLBACK_SERVERS="[]"
```

## Task Runbook

See [NTP Client](../../docs/tasks/ntp-client/README.md).

