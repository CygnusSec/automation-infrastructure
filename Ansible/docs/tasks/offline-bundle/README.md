# Offline Bundle Build

This task is run on an online machine to build an offline Ansible bundle.

## What It Does

- builds or pulls the Ansible runtime image
- builds DNS and time service images when enabled
- downloads Zabbix Agent 2 `.deb` packages when enabled
- saves the runtime image as `image-runtime/ansible-runtime.tar`
- packages the Ansible project into `dist/ansible-base-offline-<timestamp>.tar.gz`

## Key Variables

```env
RUNTIME_IMAGE=
LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local
ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES=true
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES=true
ANSIBLE_ZABBIX_AGENT_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
ANSIBLE_ZABBIX_AGENT_OFFLINE_PACKAGES="zabbix-agent2 zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql"
```

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

