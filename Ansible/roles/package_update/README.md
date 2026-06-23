# package_update

Updates selected Ubuntu packages to the latest available versions, or to exact
versions when a package entry includes `version`.

Set target hosts in `env.d/10-inventory.env`:

```env
ANSIBLE_PACKAGE_UPDATE_HOSTS="172.16.3.21,172.16.3.22,172.16.4.11"
```

Set role options in `env.d/80-package-update.env`:

```env
ANSIBLE_PACKAGE_UPDATE_ENABLED=true
ANSIBLE_PACKAGE_UPDATE_TARGET_GROUP=package_update_targets
ANSIBLE_PACKAGE_UPDATE_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE=./repo/update
ANSIBLE_PACKAGE_UPDATE_REPO_DEST=/media/installation/update
ANSIBLE_PACKAGE_UPDATE_CLEANUP_INSTALLATION_DIR=true
ANSIBLE_PACKAGE_UPDATE_INSTALLATION_DIR=/media/installation
ANSIBLE_PACKAGE_UPDATE_PACKAGES="[{name: libssl3t64}, {name: openssl}]"
```

Run:

```bash
./scripts/run-ansible.sh deploy --tags package_update
```

When `ANSIBLE_PACKAGE_UPDATE_INSTALL_FROM_LOCAL_REPO=true`, `.deb` files must
exist in `ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE`. The role copies them to
`ANSIBLE_PACKAGE_UPDATE_REPO_DEST`, installs the latest matching local `.deb`
for each package name, prints installed versions with `dpkg-query`, then clears
every item under `ANSIBLE_PACKAGE_UPDATE_INSTALLATION_DIR`, default
`/media/installation`.
