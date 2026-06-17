# Ansible Guide

This repository prepares Ubuntu hosts and runs common operations tasks:

- install baseline packages
- configure sysctl, limits, and swap
- install Docker and Docker Compose v2
- configure Zabbix Agent
- change hostnames
- change static IP addresses
- set up Docker Swarm

You can add more roles or tasks as operational needs evolve.

## Requirements

The machine running Ansible needs:

- Docker
- Docker Compose
- SSH access to target machines

Target machines need:

- an Ubuntu version supported by the current roles
- an SSH account with `sudo` privileges
- for offline runs: all required `.deb` files in `repo/`

## Main Files

- dynamic inventory: `inventories/customer-a/inventory.py`
- static inventory example: `inventories/customer-a/hosts.example`
- shared variables: `inventories/customer-a/group_vars/all.yaml`
- secret: `inventories/customer-a/secrets/`
- main playbook: `playbooks/deploy.yaml`
- quick host information playbook: `playbooks/predeploy-show-info.yaml`
- SSH key bootstrap playbook: `playbooks/ssh-copy-id.yaml`
- Ansible runner script: `scripts/run-ansible.sh`
- script build bundle: `scripts/build-offline-bundle.sh`

## Task Runbooks

Detailed English runbooks are split by task under:

```text
docs/tasks/
```

Start with the task index:

```text
docs/tasks/README.md
```

Common task runbooks:

- [Predeploy Show Info](docs/tasks/predeploy-show-info/README.md)
- [SSH Key Bootstrap](docs/tasks/ssh-copy-id/README.md)
- [Base Preparation](docs/tasks/base/README.md)
- [Prerequisite](docs/tasks/prerequisite/README.md)
- [Docker](docs/tasks/docker/README.md)
- [Hostname](docs/tasks/hostname/README.md)
- [Network](docs/tasks/network/README.md)
- [Zabbix Agent 2 Install](docs/tasks/zabbix-agent/README.md)
- [Zabbix Agent Uninstall](docs/tasks/zabbix-agent-uninstall/README.md)
- [MariaDB Native Package Remove](docs/tasks/mariadb-remove/README.md)
- [DNS And Time Services](docs/tasks/dns-time-services/README.md)
- [DNS Server](docs/tasks/dns-server/README.md)
- [Time Server](docs/tasks/time-server/README.md)
- [NTP Client](docs/tasks/ntp-client/README.md)
- [TLDH Database](docs/tasks/tldh-database/README.md)
- [External Disk](docs/tasks/external-disk/README.md)
- [Docker Swarm](docs/tasks/docker-swarm/README.md)
- [Docker Swarm iptables](docs/tasks/docker-swarm-iptables/README.md)
- [Offline Bundle Build](docs/tasks/offline-bundle/README.md)
- [Offline Control Prepare](docs/tasks/offline-control/README.md)

## Project Layout

```text
Ansible/
  playbooks/                 # executable playbooks
  roles/                     # reusable role implementations
  inventories/customer-a/    # dynamic inventory and customer variables
  scripts/                   # Docker runner and offline bundle helpers
  build/                     # Ansible runtime image Dockerfile
  repo/                      # optional offline .deb package repositories
  docs/tasks/                # task-by-task runbooks
```

## Inventory

The active inventory is dynamic:

```text
inventories/customer-a/inventory.py
```

`ansible.cfg` points to this script. The script reads host lists from `.env`
and `env.d/*.env`, then generates Ansible groups such as:

- `all_targets`
- `ssh_copy_id_targets`
- `linux`
- `zabbix_agent_targets`
- `swarm_managers`
- `swarm_workers`
- `swarm_backend_workers`
- `swarm_file_server_workers`
- `swarm_cache_ext_workers`
- `swarm_cache_int_workers`
- `dns_time_servers`

Set host lists in `env.d/10-inventory.env`. Keep environment-specific values
out of this README and use placeholder comments as a template:

```env
# ANSIBLE_ALL_TARGET_HOSTS="<control-ip>,<worker-ip-1>"
# ANSIBLE_SWARM_MANAGER_HOSTS="<manager-ip>"
# ANSIBLE_SWARM_BACKEND_WORKER_HOSTS="<backend-ip-1>,<backend-ip-2>"
# ANSIBLE_SWARM_FILE_SERVER_WORKER_HOSTS="<file-server-ip-1>,<file-server-ip-2>"
# ANSIBLE_SWARM_CACHE_SERVER_EXT_HOSTS="<cache-ext-ip-1>,<cache-ext-ip-2>"
# ANSIBLE_SWARM_CACHE_SERVER_EXT_TAGS="cache-server-ext-01,cache-server-ext-02"
# ANSIBLE_SWARM_CACHE_SERVER_INT_HOSTS="<cache-int-ip-1>,<cache-int-ip-2>"
# ANSIBLE_SWARM_CACHE_SERVER_INT_TAGS="cache-server-int-01,cache-server-int-02"
# ANSIBLE_SSH_COPY_ID_EXTRA_HOSTS="<extra-ip-1>,<extra-ip-2>"
# ANSIBLE_ZABBIX_AGENT_HOSTS="<agent-ip-1>,<agent-ip-2>"
```

Cache tag variables map positionally to cache host variables. For example,
the first host in `ANSIBLE_SWARM_CACHE_SERVER_EXT_HOSTS` gets
`node_tag=cache-server-ext-01`.

## Secret

Per-inventory secrets are stored under:

```text
inventories/customer-a/secrets/
```

Common files:

- SSH private key: `inventories/customer-a/secrets/id_rsa`
- SSH public key: `inventories/customer-a/secrets/id_rsa.pub`
- optional sudo password: `inventories/customer-a/secrets/auth.yaml`

Example `auth.yaml`:

```yaml
ansible_become_password: "your-sudo-password"
# Optional for the first SSH key bootstrap run.
ansible_password: "your-ssh-password"
```

`./scripts/run-ansible.sh` automatically loads `inventories/customer-a/secrets/auth.yaml` when the file exists.
You can also set `ANSIBLE_PASSWORD` and `ANSIBLE_BECOME_PASSWORD` in `.env`;
those values are passed as Ansible extra vars at runtime.

## Configuration Variables

Environment-specific values are managed in:

```text
.env
```

Use `.env` for common settings only:

- runtime image and offline-control mode
- SSH user and private key
- optional first-run SSH password
- optional sudo/become password
- secret vars file path

Task-specific values are split into:

```text
env.d/*.env
```

`scripts/run-ansible.sh` loads `.env` first. When you run with `--tags`, it
loads `env.d/10-inventory.env` plus the env file mapped to those tags. When you
run without `--tags`, it loads all `env.d/*.env` files. Real `env.d/*.env`
files are ignored by git; tracked templates live beside them as
`*.env.example`.

Start from the example file:

```bash
cp .env.example .env
```

Create task env files from templates when needed:

```bash
cp env.d/10-inventory.env.example env.d/10-inventory.env
cp env.d/30-zabbix-agent.env.example env.d/30-zabbix-agent.env
cp env.d/70-tldh-database.env.example env.d/70-tldh-database.env
```

Tag-to-env mapping:

| Tags | Env file |
| --- | --- |
| `base`, `prerequisite`, `docker` | `env.d/20-base.env` |
| `mariadb_remove` | `env.d/20-base.env` |
| `hostname`, `network` | `env.d/25-host-network.env` |
| `zabbix`, `zabbix_agent`, `zabbix_agent_uninstall` | `env.d/30-zabbix-agent.env` |
| `dns_time_services`, `dns_server`, `time_server`, `ntp_client` | `env.d/40-dns-time.env` |
| `external_disk` | `env.d/50-external-disk.env` |
| `docker_swarm`, `docker_swarm_iptables` | `env.d/60-docker-swarm.env` |
| `tldh_database` | `env.d/70-tldh-database.env` |

Ansible variables are mapped from environment variables in:

```text
inventories/customer-a/group_vars/all.yaml
```

The Docker wrapper loads the selected environment files, passes the resulting
`ANSIBLE_*` variables into the Ansible runtime container, and the
inventory/group variables read values with `lookup('env', ...)`.

Main variable groups:

- `prerequisite_*`
- `docker_*`
- `zabbix_agent_*`
- `hostname_*`
- `network_*`
- `docker_swarm_*`
- `dns_time_services_*`
- `dns_server_*`
- `time_server_*`
- `ntp_client_*`
- `tldh_database_*`
- `external_disk_*`

Common `.env` variables:

```env
ANSIBLE_SSH_USER=ubuntu
ANSIBLE_SSH_PRIVATE_KEY_FILE=./inventories/customer-a/secrets/id_rsa
ANSIBLE_SSH_COPY_ID_PUBLIC_KEY_FILE=./inventories/customer-a/secrets/id_rsa.pub
ANSIBLE_BECOME=true
ANSIBLE_BECOME_METHOD=sudo
```

For offline runs, prepare:

- `repo/prerequisite`
- `repo/docker`
- `repo/zabbix`

## Quick Run Guide

Use these steps for the current Docker-based Ansible workflow.

### 1. Prepare `.env`

Start from the common example when `.env` does not exist:

```bash
cp .env.example .env
```

Set the runtime image:

```env
RUNTIME_IMAGE=
LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local
```

Set SSH user and key paths:

```env
ANSIBLE_SSH_USER=bcy_admin
ANSIBLE_SSH_PRIVATE_KEY_FILE=./inventories/customer-a/secrets/id_rsa
ANSIBLE_SSH_COPY_ID_PUBLIC_KEY_FILE=./inventories/customer-a/secrets/id_rsa.pub
```

For the first password-based SSH bootstrap only, set:

```env
ANSIBLE_PASSWORD=your-ssh-password
ANSIBLE_BECOME_PASSWORD=your-sudo-password
```

Use that password only with the `ssh-copy-id` bootstrap playbook. Normal
deployments must connect with `ANSIBLE_SSH_USER` and
`ANSIBLE_SSH_PRIVATE_KEY_FILE`; privileged tasks use sudo/become. After SSH keys
are installed successfully, clear the bootstrap password:

```env
ANSIBLE_SSH_PASSWORD_AUTH=
ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE=
ANSIBLE_SSH_COMMON_ARGS=
ANSIBLE_PASSWORD=
```

Create task env files from the templates you need:

```bash
cp env.d/10-inventory.env.example env.d/10-inventory.env
cp env.d/20-base.env.example env.d/20-base.env
cp env.d/30-zabbix-agent.env.example env.d/30-zabbix-agent.env
```

For example, `./scripts/run-ansible.sh deploy --tags zabbix` loads `.env`,
`env.d/10-inventory.env`, and `env.d/30-zabbix-agent.env`.

### 2. Prepare the Runtime Image

If the control machine can build the image locally:

```bash
./scripts/run-ansible.sh predeploy-show-info --syntax-check
```

If the control machine is offline, build the bundle on an online machine:

```bash
./scripts/build-offline-bundle.sh
```

Copy and extract the generated archive on the offline control machine, then run:

```bash
cd project
./scripts/prepare-offline-control.sh
```

If you copied only the runtime tar file, pass it explicitly:

```bash
./scripts/prepare-offline-control.sh /path/to/ansible-runtime.tar
```

### 3. Copy SSH Key on the First Run

When hosts only accept SSH password login, run:

```bash
./scripts/run-ansible.sh ssh-copy-id
```

or use the wrapper:

```bash
./scripts/run-ssh-copy-id-password.sh
```

This installs `ANSIBLE_SSH_COPY_ID_PUBLIC_KEY_FILE` into `authorized_keys` for
all hosts in `ssh_copy_id_targets`. Relative key paths are resolved from the
`Ansible/` directory, for example
`./inventories/customer-a/secrets/id_rsa.pub`.

### 4. Validate Connectivity

Show host information for Swarm manager and worker hosts:

```bash
./scripts/run-ansible.sh predeploy-show-info
```

Limit to all SSH bootstrap targets:

```bash
./scripts/run-ansible.sh predeploy-show-info --limit ssh_copy_id_targets
```

Limit to Zabbix agent targets:

```bash
./scripts/run-ansible.sh predeploy-show-info --limit zabbix_agent_targets
```

### 5. Run Deployment

Check syntax:

```bash
./scripts/run-ansible.sh deploy --syntax-check
```

Run all enabled roles:

```bash
./scripts/run-ansible.sh deploy
```

Run only Zabbix agent:

```bash
./scripts/run-ansible.sh deploy --tags zabbix_agent
```

Run only Docker Swarm:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm
```

## Validation Runs

Show quick host information:

```bash
./scripts/run-ansible.sh predeploy-show-info
```

Install the configured SSH public key on all target servers:

```bash
./scripts/run-ansible.sh ssh-copy-id
```

This playbook is the Ansible equivalent of `ssh-copy-id`. It reads
`ANSIBLE_SSH_COPY_ID_PUBLIC_KEY_FILE`, or defaults to
`ANSIBLE_SSH_PRIVATE_KEY_FILE + ".pub"` when the variable is empty. If the
server still requires password login, add `ansible_password` to
`inventories/customer-a/secrets/auth.yaml` for this first run.

For the first run when hosts only accept SSH password login:

```bash
cp inventories/customer-a/secrets/auth.yaml.example inventories/customer-a/secrets/auth.yaml
```

Edit `inventories/customer-a/secrets/auth.yaml`, set `ansible_password`, then
run:

```bash
./scripts/run-ssh-copy-id-password.sh
```

That wrapper temporarily sets `ANSIBLE_SSH_PASSWORD_AUTH=true` so Ansible uses
the password from `auth.yaml` instead of the private key. After this succeeds,
the wrapper updates `.env` back to key mode:

```env
ANSIBLE_SSH_PASSWORD_AUTH=
ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE=
ANSIBLE_SSH_COMMON_ARGS=
ANSIBLE_PASSWORD=
```

Normal runs then use `ANSIBLE_SSH_PRIVATE_KEY_FILE`, for example:

```bash
./scripts/run-ansible.sh predeploy-show-info
./scripts/run-ansible.sh deploy
```

Check syntax:

```bash
./scripts/run-ansible.sh deploy --syntax-check
```

Check syntax by tag:

```bash
./scripts/run-ansible.sh deploy --syntax-check --tags network
```

## Run Online

Use this flow when the control machine can reach package registries or already
has the Ansible runtime image locally.

Prepare the control machine:

```bash
cp .env.example .env
cp env.d/10-inventory.env.example env.d/10-inventory.env
cp env.d/20-base.env.example env.d/20-base.env
```

Edit `.env` for common SSH/runtime settings. Edit `env.d/10-inventory.env` for
host lists and create the task env files needed for the tags you will run. Put
the SSH private key and optional sudo password under:

```text
inventories/customer-a/secrets/
```

Then validate and run:

```bash
./scripts/run-ansible.sh deploy --syntax-check
./scripts/run-ansible.sh predeploy-show-info
./scripts/run-ansible.sh deploy
```

If `LOCAL_RUNTIME_IMAGE` is not available locally, `scripts/run-ansible.sh`
builds it from `build/dockerfile`. If `RUNTIME_IMAGE` is set, it pulls that image
from the registry.

## Run Offline

Use this flow when the control machine has no internet access. Prepare the
offline bundle on another machine that does have network access.

On the online build machine:

```bash
cp .env.example .env
cp env.d/90-offline-bundle.env.example env.d/90-offline-bundle.env
./scripts/build-offline-bundle.sh
```

The build script also builds and saves the Dockerized DNS/time service images
when `ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES=true` or unset:

```text
project/repo/docker-images/bind9.tar
project/repo/docker-images/chrony.tar
```

It also downloads Zabbix Agent 2 offline `.deb` packages into
`project/repo/zabbix` when `ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES=true` or
unset. The default Zabbix repository package is:

```text
https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
```

The default downloaded packages are:

```text
zabbix-agent2
zabbix-agent2-plugin-mongodb
zabbix-agent2-plugin-mssql
zabbix-agent2-plugin-postgresql
```

Override `ANSIBLE_ZABBIX_AGENT_RELEASE_URL` and
`ANSIBLE_ZABBIX_AGENT_OFFLINE_PACKAGES` in `env.d/90-offline-bundle.env` if you
need a different Ubuntu or Zabbix version. The downloader image defaults to
`ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE=ubuntu:24.04`.

This creates:

```text
dist/ansible-base-offline-<timestamp>/
dist/ansible-base-offline-<timestamp>.tar.gz
```

Copy the `.tar.gz` file to the offline control machine and extract it. On the
offline control machine:

```bash
cd project
./scripts/prepare-offline-control.sh
```

The prepare script loads `../image-runtime/ansible-runtime.tar`, creates `.env`
from `.env.example` when needed, creates missing `env.d/[0-7][0-9]-*.env`
files from their examples, sets `ANSIBLE_CONTROL_OFFLINE=true`, and pins
`LOCAL_RUNTIME_IMAGE` to the packaged image name.

Before running offline, make sure these items are already present:

- Docker Engine and Docker Compose plugin on the control machine
- SSH network access from the control machine to target hosts
- target SSH key at the path configured by `ANSIBLE_SSH_PRIVATE_KEY_FILE`
- optional sudo secret at `inventories/customer-a/secrets/auth.yaml`
- local `.deb` packages under `repo/prerequisite` and `repo/docker` if target
  hosts cannot install packages from apt repositories
- local Zabbix Agent 2 `.deb` packages under `repo/zabbix` when deploying
  Zabbix Agent offline
- local service image tar files under `repo/docker-images` when deploying
  Dockerized DNS/time services offline

Then validate and run:

```bash
./scripts/run-ansible.sh deploy --syntax-check
./scripts/run-ansible.sh predeploy-show-info
./scripts/run-ansible.sh deploy
```

When `ANSIBLE_CONTROL_OFFLINE=true`, `scripts/run-ansible.sh` does not pull or
build images. If the runtime image is missing locally, it fails and asks you to
run `./scripts/prepare-offline-control.sh`.

## Run By Tag

Run the full base play:

```bash
./scripts/run-ansible.sh deploy
```

Run only prerequisite:

```bash
./scripts/run-ansible.sh deploy --tags prerequisite
```

Run only Docker:

```bash
./scripts/run-ansible.sh deploy --tags docker
```

Configure Zabbix Agent:

```bash
./scripts/run-ansible.sh deploy --tags zabbix
```

Change hostname:

```bash
./scripts/run-ansible.sh deploy --tags hostname --limit <target-host-or-ip>
```

Change IP:

```bash
./scripts/run-ansible.sh deploy --tags network --limit <target-host-or-ip>
```

Create or join Docker Swarm:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm
```

Configure Docker Swarm iptables rules separately:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables
```

Configure NTP clients:

```bash
./scripts/run-ansible.sh deploy --tags ntp_client
```

Mount external disks:

```bash
./scripts/run-ansible.sh deploy --tags external_disk
```

If you do not use `auth.yaml`, let Ansible prompt for the `sudo` password at runtime:

```bash
./scripts/run-ansible.sh deploy -K
```

## Notes When Changing Hostname And IP

`hostname` and `network` read values from `group_vars/all.yaml`, so run one host at a time with `--limit`.

Example:

```yaml
hostname_manage: true
hostname_value: "ubuntu-proxmox-01-vm"

network_manage: true
network_interface: "eth0"
network_ipv4_address: "<target-ip>"
network_ipv4_prefix_length: 24
network_ipv4_gateway: "<gateway-ip>"
network_dns_servers:
  - "<dns-ip-1>"
  - "<dns-ip-2>"
```

Notes:

- changing the hostname is usually safer than changing the IP address
- change IP addresses one host at a time
- after changing an IP address, update the matching host list in `env.d/10-inventory.env`
- the `network` role backs up `50-cloud-init.yaml` to `50-cloud-init.yaml.ansible.bak` when the file exists, then uses the new Netplan configuration to replace the old one

## Docker Swarm

To run the Swarm role, the inventory needs manager and worker groups. With the
current dynamic inventory, define these groups with the `ANSIBLE_SWARM_*`
variables in `env.d/10-inventory.env`. Static inventories can use a layout
like this:

```ini
[swarm_managers]
manager-01 ansible_host=<manager-ip> docker_swarm_advertise_addr=<manager-ip>

[swarm_app_workers]
app-worker-01 ansible_host=<app-worker-ip-1> docker_swarm_advertise_addr=<app-worker-ip-1>
app-worker-02 ansible_host=<app-worker-ip-2> docker_swarm_advertise_addr=<app-worker-ip-2>
app-worker-03 ansible_host=<app-worker-ip-3> docker_swarm_advertise_addr=<app-worker-ip-3>

[swarm_data_workers]
data-worker-01 ansible_host=<data-worker-ip-1> docker_swarm_advertise_addr=<data-worker-ip-1>
data-worker-02 ansible_host=<data-worker-ip-2> docker_swarm_advertise_addr=<data-worker-ip-2>

[swarm_workers:children]
swarm_app_workers
swarm_data_workers
```

Common variables:

```yaml
docker_swarm_enabled: true
docker_swarm_manager_group: swarm_managers
docker_swarm_worker_group: swarm_workers
docker_swarm_listen_addr: "<listen-ip>:2377"
docker_swarm_port: 2377
docker_swarm_force_reset: false
docker_swarm_manager_addr: ""
docker_swarm_manage_iptables: false
docker_swarm_iptables_source_cidr: "<source-cidr>"
docker_swarm_manage_encrypted_overlay_esp: false
docker_swarm_service_ports:
  - port: 80
    protocol: tcp
```

The first host in `swarm_managers` becomes the primary manager. The role
initializes Swarm there, reads worker/manager join tokens, and joins remaining
managers and workers automatically. If `docker_swarm_manager_addr` is empty, the
role uses the primary manager's `docker_swarm_advertise_addr`, then `ansible_host`,
then `inventory_hostname`.

Docker Swarm iptables is a separate run. `--tags docker_swarm` only initializes
and joins Swarm nodes. If `docker_swarm_manage_iptables: true`, run
`--tags docker_swarm_iptables` to open the standard Swarm iptables rules:
`2377/tcp` on manager nodes, `7946/tcp`, `7946/udp`, and `4789/udp` on all
manager/worker nodes. Set `docker_swarm_manage_encrypted_overlay_esp: true` to
allow IP protocol `50` (`esp`) when using encrypted overlay networks. Add
published application ports to `docker_swarm_service_ports`.

Node labels can be assigned by inventory group:

```yaml
docker_swarm_group_labels:
  swarm_app_workers:
    workload: app
    disk: ssd
  swarm_data_workers:
    workload: data
    disk: hdd
```

Host-level `docker_swarm_node_labels` can add or override labels for a specific
node.

## Zabbix Agent

The Ansible control machine is treated as the Zabbix server. Target hosts get a
Zabbix Agent configuration that points back to that control machine.

Set these values in `env.d/30-zabbix-agent.env`. Use comments as a template
and fill the real server address only in your local env file:

```env
# ANSIBLE_ZABBIX_AGENT_ENABLED=true
# ANSIBLE_ZABBIX_SERVER_HOST=<zabbix-server-ip-or-dns>
# ANSIBLE_ZABBIX_AGENT_HOSTNAME=
# ANSIBLE_ZABBIX_AGENT_MANAGE_APT_REPO=true
# ANSIBLE_ZABBIX_AGENT_RELEASE_URL=https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
# ANSIBLE_ZABBIX_AGENT_PACKAGES=[zabbix-agent2, zabbix-agent2-plugin-mongodb, zabbix-agent2-plugin-mssql, zabbix-agent2-plugin-postgresql]
# ANSIBLE_ZABBIX_AGENT_SERVICE_NAME=zabbix-agent2
# ANSIBLE_ZABBIX_AGENT_CONFIG_FILE=/etc/zabbix/zabbix_agent2.conf
# ANSIBLE_ZABBIX_AGENT_REMOVE_LEGACY_AGENT=true
```

`ANSIBLE_ZABBIX_SERVER_HOST` must be the IP address or DNS name of the control
machine as seen from target hosts. Keep `ANSIBLE_ZABBIX_AGENT_HOSTNAME=` empty
for normal use so each agent uses its own machine hostname from
`ansible_hostname`, falling back to `inventory_hostname` only if facts are not
available. Set it only when you intentionally want to force the same hostname
for every targeted agent. `ANSIBLE_ZABBIX_AGENT_MANAGE_APT_REPO=true` installs
the Zabbix 7.0 Ubuntu 24.04 release package before online apt installs. The
role also removes legacy `zabbix-agent` by default before installing Agent 2.

For offline target hosts, place Zabbix agent `.deb` packages under:

```text
repo/zabbix/
```

Then set:

```env
ANSIBLE_ZABBIX_AGENT_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_ZABBIX_AGENT_REPO_SOURCE=./repo/zabbix
ANSIBLE_ZABBIX_AGENT_REPO_DEST=/media/installation/zabbix
```

On the online build machine, `./scripts/build-offline-bundle.sh` downloads
these Zabbix Agent 2 packages automatically by using the Zabbix 7.0 Ubuntu
24.04 release package. The downloaded packages are included in the offline
bundle under `project/repo/zabbix`.

Run only Zabbix Agent configuration:

```bash
./scripts/run-ansible.sh deploy --tags zabbix
```

Uninstall Zabbix Agent and plugins from the target group:

```bash
./scripts/run-ansible.sh deploy --tags zabbix_agent_uninstall
```

By default uninstall stops both `zabbix-agent2` and legacy `zabbix-agent`, then
removes `zabbix-agent2`, the MongoDB/MSSQL/PostgreSQL agent2 plugins, and the
legacy `zabbix-agent` package if it exists. Set
`ANSIBLE_ZABBIX_AGENT_UNINSTALL_REMOVE_LOCAL_REPO=true` if the copied offline
package directory under `ANSIBLE_ZABBIX_AGENT_REPO_DEST` should also be removed.

## Dockerized DNS And Time Servers

DNS and time services are deployed as Docker containers. The role does not pull
images from a registry during deployment. For offline environments, prepare
image tar files on an online machine and copy them to the Ansible control
machine.

The target hosts must already have Docker installed and running. This role only
loads service images from tar files and starts containers; it does not install
Docker or any native DNS/time packages.

Target hosts are configured in `env.d/10-inventory.env` or
`env.d/40-dns-time.env`:

```env
# ANSIBLE_DNS_TIME_SERVER_HOSTS="<dns-time-ip-1>,<dns-time-ip-2>"
```

Default local image tar paths:

```text
repo/docker-images/bind9.tar
repo/docker-images/chrony.tar
```

On the offline control machine, verify the files are present before running:

```bash
ls -lh repo/docker-images/bind9.tar repo/docker-images/chrony.tar
```

The normal offline bundle flow creates those tar files automatically:

```bash
./scripts/build-offline-bundle.sh
```

It builds the service images from:

```text
build/dns-server.Dockerfile
build/time-server.Dockerfile
```

Then saves them into `repo/docker-images/` before packaging the bundle. Set the
matching image names in `env.d/40-dns-time.env`:

```env
# ANSIBLE_DNS_TIME_SERVICES_ENABLED=true
# ANSIBLE_DNS_TIME_SERVER_HOSTS="<dns-time-ip-1>,<dns-time-ip-2>"
# ANSIBLE_DNS_TIME_SERVICES_LOAD_IMAGES=true
# ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES=true
#
# ANSIBLE_DNS_SERVER_IMAGE=local/bind9:offline
# ANSIBLE_DNS_SERVER_IMAGE_TAR=./repo/docker-images/bind9.tar
# ANSIBLE_DNS_SERVER_ALLOW_QUERY="[<allowed-cidr>]"
# ANSIBLE_DNS_SERVER_FORWARDERS=[]
# ANSIBLE_DNS_SERVER_ZONE_SERIAL=1
# ANSIBLE_DNS_SERVER_ZONES="[{name: example.local, records: [{name: api, type: A, value: <app-ip>}, {name: file, type: A, value: <file-ip>}, {name: cache, type: A, value: <cache-ip>}]}]"
#
# ANSIBLE_TIME_SERVER_IMAGE=local/chrony:offline
# ANSIBLE_TIME_SERVER_IMAGE_TAR=./repo/docker-images/chrony.tar
# ANSIBLE_TIME_SERVER_ALLOW="[<allowed-cidr>]"
# ANSIBLE_TIME_SERVER_UPSTREAM_SERVERS=[]
```

The image tag in each tar file must match the configured image name. For
example, `ANSIBLE_DNS_SERVER_IMAGE=local/bind9:offline` requires the tar file to
contain `local/bind9:offline`. The default commands expect the DNS image to
provide `named` and the time image to provide `chronyd`.

The containers run with host networking so DNS listens on port `53` and the
time service listens on UDP port `123` on the target host.

Example DNS records:

```text
api.example.local    A <app-ip>
file.example.local   A <file-ip>
cache.example.local  A <cache-ip>
```

Verify DNS lookup from a client:

```bash
dig @<dns-server-ip> api.example.local +short
dig @<dns-server-ip> file.example.local +short
dig @<dns-server-ip> cache.example.local +short
```

Run only DNS and time services:

```bash
./scripts/run-ansible.sh deploy --tags dns_time_services
```

Run only one side:

```bash
./scripts/run-ansible.sh deploy --tags dns_server
./scripts/run-ansible.sh deploy --tags time_server
```

## NTP Clients

After the time server containers are running, configure the remaining servers
as NTP clients:

```env
# ANSIBLE_NTP_CLIENT_ENABLED=true
# ANSIBLE_NTP_CLIENT_TARGET_GROUP=all_targets:!dns_time_servers
# ANSIBLE_NTP_CLIENT_SERVERS="[<time-server-ip-1>, <time-server-ip-2>]"
# ANSIBLE_NTP_CLIENT_FALLBACK_SERVERS=[]
```

Run only NTP client configuration:

```bash
./scripts/run-ansible.sh deploy --tags ntp_client
```

This role writes a `systemd-timesyncd` drop-in file on the target hosts:

```text
/etc/systemd/timesyncd.conf.d/10-ansible-ntp.conf
```

It does not install packages during the NTP client run. If a target does not
have `systemd-timesyncd`, add that package to the offline prerequisite
repository before running this role.

## External Disk Mounts

Use the `external_disk` role to partition, format, and mount a dedicated data
disk on selected hosts.

Target hosts are configured in `env.d/50-external-disk.env`:

```env
# ANSIBLE_EXTERNAL_DISK_HOSTS="<disk-host-ip-1>,<disk-host-ip-2>"
```

Disk settings:

```env
ANSIBLE_EXTERNAL_DISK_ENABLED=true
ANSIBLE_EXTERNAL_DISK_TARGET_GROUP=external_disk_targets
ANSIBLE_EXTERNAL_DISK_DEVICE=/dev/sdb
ANSIBLE_EXTERNAL_DISK_PARTITION=/dev/sdb1
ANSIBLE_EXTERNAL_DISK_MOUNT_PATH=/mnt/data
ANSIBLE_EXTERNAL_DISK_FSTYPE=ext4
ANSIBLE_EXTERNAL_DISK_MOUNT_OPTS=defaults
ANSIBLE_EXTERNAL_DISK_CREATE_PARTITION=true
ANSIBLE_EXTERNAL_DISK_FORMAT=true
```

Run only external disk mounting:

```bash
./scripts/run-ansible.sh deploy --tags external_disk
```

The role creates `/dev/sdb1` only when it is missing and formats it only when no
filesystem exists. It persists the mount in `/etc/fstab` using the partition
UUID, then mounts `/mnt/data`.

## Verify After Running

Check Docker:

```bash
RUNTIME_IMAGE=ansible-base-runtime:local LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local \
  docker compose -f docker-compose.yaml run --rm ansible \
  ansible linux -m command -a 'docker --version'
```

Check Docker Compose:

```bash
RUNTIME_IMAGE=ansible-base-runtime:local LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local \
  docker compose -f docker-compose.yaml run --rm ansible \
  ansible linux -m command -a 'docker compose version'
```

Check the Docker service:

```bash
RUNTIME_IMAGE=ansible-base-runtime:local LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local \
  docker compose -f docker-compose.yaml run --rm ansible \
  ansible linux -m command -a 'systemctl is-active docker'
```

## Common Errors

- SSH cannot connect to the host: check the inventory, firewall, user, and SSH key
- `sudo` fails: check `inventories/customer-a/secrets/auth.yaml` or rerun with `-K`
- offline repo is empty: the role fails because it cannot find `.deb` files
- IP address changed but inventory was not updated: later commands still point to the old IP address
- Swarm run without `swarm_managers` or `swarm_workers` groups in inventory: the Swarm play is skipped or has no matching hosts
- offline control image is missing: run `./scripts/prepare-offline-control.sh`
  from the extracted bundle before running Ansible
