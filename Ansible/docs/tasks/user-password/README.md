# User Password

Change a local Linux user password on selected hosts.

## Environment

Set these values in `env.d/20-base.env`:

```env
ANSIBLE_USER_PASSWORD_TARGET_GROUP=all_targets
ANSIBLE_USER_PASSWORD_USERNAME=bcy_admin
ANSIBLE_USER_PASSWORD_VALUE='new-password'
```

The password task uses `no_log: true`, so Ansible will hide the username and
password values from task output. Keep real passwords only in ignored runtime
env files such as `env.d/20-base.env`; do not commit real password values.

## Run

```bash
./scripts/run-ansible.sh deploy --tags user_password
```

Run for one host by IP:

```bash
./scripts/run-ansible.sh deploy --tags user_password --limit 172.16.3.28
```

Run for multiple hosts by IP:

```bash
./scripts/run-ansible.sh deploy --tags user_password --limit 172.16.3.28,172.16.3.29
```

The task calls `chpasswd` on each target host. It does not install packages,
change SSH configuration, or run other maintenance tasks.
