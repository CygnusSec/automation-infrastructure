# Prerequisite

This task prepares Ubuntu hosts for the rest of the automation.

## What It Does

- validates the target OS family and distribution
- installs baseline packages from apt or a local `.deb` repository
- writes sysctl values
- writes system limits
- disables swap when configured
- sets timezone when configured
- disables UFW when configured

## Key Variables

```env
ANSIBLE_TARGET_OS_FAMILY=Debian
ANSIBLE_TARGET_DISTRIBUTION=Ubuntu
ANSIBLE_PREREQUISITE_DISABLE_SWAP=true
ANSIBLE_PREREQUISITE_DISABLE_UFW=false
ANSIBLE_PREREQUISITE_TIMEZONE=
ANSIBLE_PREREQUISITE_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_PREREQUISITE_REPO_SOURCE=./repo/prerequisite
ANSIBLE_PREREQUISITE_REPO_DEST=/media/installation/prerequisite
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags prerequisite
```

## Offline Notes

When `ANSIBLE_PREREQUISITE_INSTALL_FROM_LOCAL_REPO=true`, put required `.deb`
files under:

```text
Ansible/repo/prerequisite/
```

The role copies them to `ANSIBLE_PREREQUISITE_REPO_DEST` on the target and runs
`apt-get install` from that directory.

`scripts/build-offline-bundle.sh` can download prerequisite `.deb` packages
into `Ansible/repo/prerequisite/` before packaging the bundle. Configure these
in `env.d/90-offline-bundle.env`:

```env
ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES=true
ANSIBLE_PREREQUISITE_DOWNLOAD_IMAGE=ubuntu:24.04
ANSIBLE_PREREQUISITE_OFFLINE_PACKAGES="apt-transport-https ca-certificates curl gnupg ipset ipset-persistent iptables-persistent lsb-release net-tools netfilter-persistent openssh-client python3 python3-apt python3-pip rsync sshpass telnet traceroute unzip vim wget libheif1 libheif-plugin-aomenc libheif-plugin-libde265 systemd libsystemd-shared libnss-systemd libpam-systemd systemd-resolved systemd-timesyncd udev libudev1"
ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES="libssl3t64 openssl inetutils-telnet telnet vim vim-common vim-runtime vim-tiny xxd"
```

`ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES` is downloaded separately into
`ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE`, default `Ansible/repo/update/`, so the
targeted package update role can install latest local versions offline.
