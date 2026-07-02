# Package Update

Updates selected Ubuntu packages to the latest available versions, or to exact
fixed versions when a package entry includes `version`.

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
ANSIBLE_PACKAGE_UPDATE_PACKAGES="[{name: vim, version: '2:9.1.0016-1ubuntu7.15'}, {name: vim-common, version: '2:9.1.0016-1ubuntu7.15'}, {name: vim-runtime, version: '2:9.1.0016-1ubuntu7.15'}, {name: vim-tiny, version: '2:9.1.0016-1ubuntu7.15'}, {name: xxd, version: '2:9.1.0016-1ubuntu7.15'}, {name: python3-wheel, version: '0.42.0-2ubuntu0.1~esm1'}]"
ANSIBLE_PYTHON3_PIP_REMOVE_TARGET_GROUP=package_update_targets
ANSIBLE_PYTHON3_PIP_REMOVE_PACKAGES="[python3-pip]"
ANSIBLE_PYTHON3_PIP_REMOVE_PURGE=false
ANSIBLE_PYTHON3_PIP_REMOVE_AUTOREMOVE=true
```

## Current Package List

```text
vim=2:9.1.0016-1ubuntu7.15
vim-common=2:9.1.0016-1ubuntu7.15
vim-runtime=2:9.1.0016-1ubuntu7.15
vim-tiny=2:9.1.0016-1ubuntu7.15
xxd=2:9.1.0016-1ubuntu7.15
python3-wheel=0.42.0-2ubuntu0.1~esm1
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags package_update
```

For the same package set under the CVE remediation tag:

```bash
./scripts/run-ansible.sh deploy --tags cve_update
```

Remove `python3-pip` when it is not required:

```bash
./scripts/run-ansible.sh deploy --tags python3_pip_remove
```

## Offline Notes

For offline runs, put the `.deb` files in:

```text
Ansible/repo/update/
```

The offline bundle builder downloads the latest available packages from
`ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES` in `env.d/90-offline-bundle.env`.
For each package entry without `version`, the role installs the highest local
`.deb` version found in `repo/update`. After install, the role prints installed
versions and clears every item under `ANSIBLE_PACKAGE_UPDATE_INSTALLATION_DIR`,
default `/media/installation`.
Entries with `+esm1` fixed versions require Ubuntu Pro/ESM packages to be
present in `repo/update` before an offline run.
