# Time Server

This task deploys only the Chrony time server container.

## What It Does

- renders `chrony.conf`
- loads `local/chrony:offline` from `repo/docker-images/chrony.tar` when needed
- runs the time server container on host networking

## Key Variables

```env
ANSIBLE_TIME_SERVER_ENABLED=true
ANSIBLE_TIME_SERVER_IMAGE=local/chrony:offline
ANSIBLE_TIME_SERVER_IMAGE_TAR=./repo/docker-images/chrony.tar
ANSIBLE_TIME_SERVER_ALLOW="[172.16.0.0/16]"
ANSIBLE_TIME_SERVER_UPSTREAM_SERVERS="[]"
ANSIBLE_TIME_SERVER_LOCAL_STRATUM=10
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags time_server
```

## Verification

From a client host:

```bash
timedatectl timesync-status
```

