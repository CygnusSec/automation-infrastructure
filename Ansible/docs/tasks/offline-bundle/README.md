# Offline Bundle Build

This task is run on an online machine to build an offline Ansible bundle.

## What It Does

- builds or pulls the Ansible runtime image
- builds DNS and time service images when enabled
- downloads Zabbix Agent 2 `.deb` packages when enabled
- downloads Zabbix Server `.deb` packages when enabled
- saves the runtime image as `image-runtime/ansible-runtime.tar`
- packages the Ansible project into `dist/ansible-base-offline-<timestamp>.tar.gz`
- excludes local `.env`, `.env.example`, `env.d/*.env`, `env.d/*.env.example`,
  SSH private/public keys, and local secret YAML files from the initial project
  copy
- copies real `.env` and `env.d/*.env` values by default, or copies
  `.env.example` and `env.d/*.env.example` as templates when disabled

## Key Variables

```env
RUNTIME_IMAGE=
LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local
ANSIBLE_OFFLINE_BUNDLE_INCLUDE_REAL_ENV=true
ANSIBLE_OFFLINE_BUNDLE_BUILD_ALL=true
ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES=true
ANSIBLE_DNS_SERVER_BUILD_IMAGE=true
ANSIBLE_TIME_SERVER_BUILD_IMAGE=true
ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES=true
ANSIBLE_PREREQUISITE_OFFLINE_PACKAGES="apt-transport-https ca-certificates curl gnupg ipset ipset-persistent iptables-persistent lsb-release net-tools netfilter-persistent openssh-client python3 python3-apt python3-pip rsync sshpass telnet traceroute unzip vim wget libheif1 libheif-plugin-aomenc libheif-plugin-libde265 systemd libsystemd-shared libnss-systemd libpam-systemd systemd-resolved systemd-timesyncd udev libudev1"
ANSIBLE_PACKAGE_UPDATE_DOWNLOAD_PACKAGES=true
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES=true
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE=ubuntu:24.04
ANSIBLE_ZABBIX_AGENT_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
ANSIBLE_ZABBIX_AGENT_OFFLINE_PACKAGES="zabbix-agent2"
ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES=true
ANSIBLE_ZABBIX_SERVER_REPO_SOURCE=./repo/zabbix-server
ANSIBLE_ZABBIX_SERVER_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
ANSIBLE_ZABBIX_SERVER_OFFLINE_PACKAGES="zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent systemd-sysv"
ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE=./repo/update
ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES="vim=2:9.1.0016-1ubuntu7.15 vim-common=2:9.1.0016-1ubuntu7.15 vim-runtime=2:9.1.0016-1ubuntu7.15 vim-tiny=2:9.1.0016-1ubuntu7.15 xxd=2:9.1.0016-1ubuntu7.15 python3-pip=24.0+dfsg-1ubuntu1.3+esm1 python3-wheel=0.42.0-2ubuntu0.1~esm1"
```

Keep `ANSIBLE_OFFLINE_BUNDLE_INCLUDE_REAL_ENV=true` in
`env.d/90-offline-bundle.env` when the bundle must include the current real
`.env` and `env.d/*.env` files with populated values. Set it to `false` only
when the bundle should be safe to hand off with templates only.

## Build Flags

`ANSIBLE_OFFLINE_BUNDLE_BUILD_ALL=true` enables every downloadable/buildable
artifact by default.

Set `ANSIBLE_OFFLINE_BUNDLE_BUILD_ALL=false`, then enable only the repo or
service that must be refreshed:

```env
ANSIBLE_OFFLINE_BUNDLE_BUILD_ALL=false
ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES=true
ANSIBLE_PACKAGE_UPDATE_DOWNLOAD_PACKAGES=false
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES=false
ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES=false
ANSIBLE_DNS_SERVER_BUILD_IMAGE=false
ANSIBLE_TIME_SERVER_BUILD_IMAGE=false
```

Available per-artifact flags:

```text
ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES
ANSIBLE_PACKAGE_UPDATE_DOWNLOAD_PACKAGES
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES
ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES
ANSIBLE_DNS_SERVER_BUILD_IMAGE
ANSIBLE_TIME_SERVER_BUILD_IMAGE
```

The Zabbix package downloader runs in `ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE`.
Agent packages are written to `repo/zabbix`, while server packages are written
to `repo/zabbix-server` by default.
Package update `.deb` files are written to `repo/update`; package specs can pin
versions with `name=version`. Unpinned package names download the latest
available version from the online apt repository at build time.
Packages whose fixed versions end in `+esm1` are Ubuntu ESM packages. Build the
bundle on a machine with Ubuntu Pro/ESM access, or copy those `.deb` files into
`repo/update` manually before deploying offline.
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
