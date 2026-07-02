# Logrotate Size Limit

Configure Ubuntu `logrotate` to delete matching log files when they reach a
size limit.

## Environment

Set these values in `env.d/20-base.env`:

```env
ANSIBLE_LOGROTATE_SIZE_LIMIT_TARGET_GROUP=all_targets
ANSIBLE_LOGROTATE_SIZE_LIMIT_CONF=/etc/logrotate.d/ansible-size-limit
ANSIBLE_LOGROTATE_SIZE_LIMIT_SIZE=1G
ANSIBLE_LOGROTATE_SIZE_LIMIT_PATHS='["/var/log/*.log", "/var/log/syslog", "/var/log/messages", "/var/log/auth.log", "/var/log/kern.log", "/var/log/daemon.log", "/var/log/user.log", "/var/log/mail.log", "/var/log/audit/*.log", "/var/log/*/*.log", "/var/log/*/*/*.log"]'
```

`rotate 0` removes rotated files. `copytruncate` keeps the active log path in
place and truncates it after rotation, which avoids requiring services to reopen
their log files.

The default path list covers common Ubuntu logs including `syslog`, `auth.log`,
kernel/user/daemon/mail logs, `auditd` logs under `/var/log/audit`, and nested
`*.log` files under `/var/log`.

## Run

```bash
./scripts/run-ansible.sh deploy --tags logrotate_size_limit
```

Run for one host by IP:

```bash
./scripts/run-ansible.sh deploy --tags logrotate_size_limit --limit 172.16.3.28
```

The task writes only the configured logrotate file and validates it with
`logrotate --debug`. It does not rotate logs immediately.
