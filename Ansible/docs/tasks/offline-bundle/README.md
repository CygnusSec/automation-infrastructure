# Offline Bundle Build

This task is run on an online machine to build an offline Ansible bundle.

## What It Does

- builds or pulls the Ansible runtime image
- builds DNS and time service images when enabled
- downloads Zabbix Agent 2 `.deb` packages when enabled
- saves the runtime image as `image-runtime/ansible-runtime.tar`
- packages the Ansible project into `dist/ansible-base-offline-<timestamp>.tar.gz`
- excludes local `.env`, `env.d/*.env`, SSH private/public keys, and local
  secret YAML files from the packaged project

## Key Variables

```env
RUNTIME_IMAGE=
LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local
ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES=true
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES=true
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE=ubuntu:24.04
ANSIBLE_ZABBIX_AGENT_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
ANSIBLE_ZABBIX_AGENT_OFFLINE_PACKAGES="zabbix-agent2"
```

The Zabbix package downloader runs in `ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE`.
If apt reports invalid repository signatures, first check Docker disk space and
the host clock on the online build machine.

## Command

```bash
cd Ansible
./scripts/build-offline-bundle.sh
```

## Output

```text
Ansible/dist/ansible-base-offline-<timestamp>/
Ansible/dist/ansible-base-offline-<timestamp>.tar.gz
```

Copy the `.tar.gz` file to the offline control machine and extract it.
