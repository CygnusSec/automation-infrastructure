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
ANSIBLE_NTP_CLIENT_SERVERS="[<time-server-ip-1>, <time-server-ip-2>]"
ANSIBLE_NTP_CLIENT_FALLBACK_SERVERS="[]"
```

## Task Runbook

See [NTP Client](../../docs/tasks/ntp-client/README.md).
