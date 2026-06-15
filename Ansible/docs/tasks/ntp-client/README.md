# NTP Client

This task configures targets to use the internal time servers through
`systemd-timesyncd`.

## What It Does

- validates configured NTP servers
- writes a `systemd-timesyncd` drop-in
- enables NTP synchronization
- enables and starts `systemd-timesyncd`

## Key Variables

```env
ANSIBLE_NTP_CLIENT_ENABLED=true
ANSIBLE_NTP_CLIENT_TARGET_GROUP=all_targets:!dns_time_servers
ANSIBLE_NTP_CLIENT_SERVERS="[172.16.3.200, 172.16.3.201]"
ANSIBLE_NTP_CLIENT_FALLBACK_SERVERS="[]"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags ntp_client
```

## Verification

```bash
timedatectl status
timedatectl timesync-status
```

