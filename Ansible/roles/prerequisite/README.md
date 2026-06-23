# prerequisite

Ubuntu baseline role.

It validates Ubuntu, installs common packages, applies sysctl values, writes
system limits, disables swap by default, and can optionally disable UFW or set
timezone.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags prerequisite
```

## Key Variables

```env
ANSIBLE_PREREQUISITE_DISABLE_SWAP=true
ANSIBLE_PREREQUISITE_DISABLE_UFW=false
ANSIBLE_PREREQUISITE_TIMEZONE=
ANSIBLE_PREREQUISITE_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_PREREQUISITE_REPO_SOURCE=./repo/prerequisite
ANSIBLE_PREREQUISITE_REPO_DEST=/media/installation/prerequisite
```

Offline bundles can download prerequisite `.deb` files, including `ipset`,
`ipset-persistent`, `iptables-persistent`, and `netfilter-persistent`, with
these variables in `env.d/90-offline-bundle.env`:

```env
ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES=true
ANSIBLE_PREREQUISITE_DOWNLOAD_IMAGE=ubuntu:24.04
ANSIBLE_PREREQUISITE_OFFLINE_PACKAGES="apt-transport-https ca-certificates curl gnupg ipset ipset-persistent iptables-persistent lsb-release net-tools netfilter-persistent openssh-client python3 python3-apt python3-pip rsync sshpass telnet traceroute unzip vim wget"
```

## Task Runbook

See [Prerequisite](../../docs/tasks/prerequisite/README.md).
