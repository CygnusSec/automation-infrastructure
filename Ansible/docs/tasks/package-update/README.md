# Package Update

Updates selected Ubuntu packages to exact fixed versions.

## Target Hosts

Set target hosts in `env.d/10-inventory.env`:

```env
ANSIBLE_PACKAGE_UPDATE_HOSTS="172.16.3.21,172.16.3.22,172.16.4.11"
```

Current target list:

```text
172.16.3.21-172.16.3.35
172.16.4.11-172.16.4.14
```

## Key Variables

Set role options in `env.d/80-package-update.env`:

```env
ANSIBLE_PACKAGE_UPDATE_ENABLED=true
ANSIBLE_PACKAGE_UPDATE_TARGET_GROUP=package_update_targets
ANSIBLE_PACKAGE_UPDATE_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE=./repo/update
ANSIBLE_PACKAGE_UPDATE_REPO_DEST=/media/installation/update
ANSIBLE_PACKAGE_UPDATE_CLEANUP_INSTALLATION_DIR=true
ANSIBLE_PACKAGE_UPDATE_INSTALLATION_DIR=/media/installation
ANSIBLE_PACKAGE_UPDATE_PACKAGES="[{name: libssl3t64, version: 3.0.13-0ubuntu3.11}, {name: openssl, version: 3.0.13-0ubuntu3.11}]"
```

## Fixed Versions

```text
libssl3t64       3.0.13-0ubuntu3.11
openssl          3.0.13-0ubuntu3.11
inetutils-telnet 2:2.5-3ubuntu4.2
telnet           0.17+2.5-3ubuntu4.2
vim              2:9.1.0016-1ubuntu7.15
vim-common       2:9.1.0016-1ubuntu7.15
vim-runtime      2:9.1.0016-1ubuntu7.15
vim-tiny         2:9.1.0016-1ubuntu7.15
xxd              2:9.1.0016-1ubuntu7.15
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags package_update
```

## Offline Notes

For offline runs, put the fixed `.deb` files in:

```text
Ansible/repo/update/
```

The offline bundle builder downloads the pinned versions from
`ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES` in `env.d/90-offline-bundle.env`.
After package install and version verification, the role clears every item under
`ANSIBLE_PACKAGE_UPDATE_INSTALLATION_DIR`, default `/media/installation`.
