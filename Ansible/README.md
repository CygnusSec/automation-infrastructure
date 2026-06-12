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

## Project Layout

```text
Ansible/
  playbooks/                 # executable playbooks
  roles/                     # reusable role implementations
  inventories/customer-a/    # dynamic inventory and customer variables
  scripts/                   # Docker runner and offline bundle helpers
  build/                     # Ansible runtime image Dockerfile
  repo/                      # optional offline .deb package repositories
  docs/                      # extended operational notes
```

## Inventory

The active inventory is dynamic:

```text
inventories/customer-a/inventory.py
```

`ansible.cfg` points to this script. The script reads host lists from `.env` and
generates Ansible groups such as:

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

Set host lists in `.env`:

```env
ANSIBLE_ALL_TARGET_HOSTS="172.16.5.3,172.16.3.21"
ANSIBLE_SWARM_MANAGER_HOSTS="172.16.5.3"
ANSIBLE_SWARM_BACKEND_WORKER_HOSTS="172.16.3.21,172.16.3.22"
ANSIBLE_SWARM_FILE_SERVER_WORKER_HOSTS="172.16.3.25,172.16.3.26"
ANSIBLE_SWARM_CACHE_SERVER_EXT_HOSTS="172.16.3.27,172.16.3.37"
ANSIBLE_SWARM_CACHE_SERVER_EXT_TAGS="cache-server-ext-01,cache-server-ext-02"
ANSIBLE_SWARM_CACHE_SERVER_INT_HOSTS="172.16.4.17,172.16.4.18"
ANSIBLE_SWARM_CACHE_SERVER_INT_TAGS="cache-server-int-01,cache-server-int-02"
ANSIBLE_SSH_COPY_ID_EXTRA_HOSTS="172.16.3.24,172.16.3.28"
ANSIBLE_ZABBIX_AGENT_HOSTS="172.16.3.21,172.16.3.22"
```

Cache tag variables map positionally to cache host variables. For example,
`172.16.3.27` gets `node_tag=cache-server-ext-01`.

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

Start from the example file:

```bash
cp .env.example .env
```

Ansible variables are mapped from environment variables in:

```text
inventories/customer-a/group_vars/all.yaml
```

The Docker wrapper loads `.env`, passes it into the Ansible runtime container,
and the inventory/group variables read values with `lookup('env', ...)`.

Main variable groups:

- `prerequisite_*`
- `docker_*`
- `zabbix_agent_*`
- `hostname_*`
- `network_*`
- `docker_swarm_*`

Common environment variables:

```env
ANSIBLE_MANAGER_1_HOST=192.168.1.143
ANSIBLE_SSH_USER=ubuntu
ANSIBLE_SSH_PRIVATE_KEY_FILE=./inventories/customer-a/secrets/id_rsa
ANSIBLE_SSH_COPY_ID_PUBLIC_KEY_FILE=./inventories/customer-a/secrets/id_rsa.pub
ANSIBLE_HOSTNAME_VALUE=ubuntu-proxmox-01-vm
ANSIBLE_NETWORK_INTERFACE=ens34
ANSIBLE_NETWORK_IPV4_ADDRESS=192.168.1.151
ANSIBLE_NETWORK_IPV4_GATEWAY=192.168.1.1
ANSIBLE_DOCKER_SWARM_ENABLED=true
ANSIBLE_ZABBIX_AGENT_ENABLED=true
ANSIBLE_ZABBIX_SERVER_HOST=192.168.1.10
```

For offline runs, prepare:

- `repo/prerequisite`
- `repo/docker`
- `repo/zabbix`

## Quick Run Guide

Use these steps for the current Docker-based Ansible workflow.

### 1. Prepare `.env`

Start from the example when `.env` does not exist:

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

For the first password-based SSH bootstrap, set:

```env
ANSIBLE_SSH_PASSWORD_AUTH=true
ANSIBLE_SSH_COMMON_ARGS="-o PubkeyAuthentication=no -o PreferredAuthentications=password"
ANSIBLE_PASSWORD=your-ssh-password
ANSIBLE_BECOME_PASSWORD=your-sudo-password
```

After SSH keys are installed successfully, change these back:

```env
ANSIBLE_SSH_PASSWORD_AUTH=false
ANSIBLE_PASSWORD=
ANSIBLE_BECOME_PASSWORD=
```

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
all hosts in `ssh_copy_id_targets`.

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
normal runs can use `./scripts/run-ansible.sh ssh-copy-id` or
`./scripts/run-ansible.sh deploy`.

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
```

Edit `.env` for the target hosts, SSH key, hostname, network settings, and
Swarm settings. Put the SSH private key and optional sudo password under:

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
./scripts/build-offline-bundle.sh
```

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
from `.env.example` when needed, sets `ANSIBLE_CONTROL_OFFLINE=true`, and pins
`LOCAL_RUNTIME_IMAGE` to the packaged image name.

Before running offline, make sure these items are already present:

- Docker Engine and Docker Compose plugin on the control machine
- SSH network access from the control machine to target hosts
- target SSH key at the path configured by `ANSIBLE_SSH_PRIVATE_KEY_FILE`
- optional sudo secret at `inventories/customer-a/secrets/auth.yaml`
- local `.deb` packages under `repo/prerequisite` and `repo/docker` if target
  hosts cannot install packages from apt repositories

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
./scripts/run-ansible.sh deploy --tags hostname --limit 192.168.1.143
```

Change IP:

```bash
./scripts/run-ansible.sh deploy --tags network --limit 192.168.1.143
```

Create or join Docker Swarm:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm
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
network_ipv4_address: "192.168.1.151"
network_ipv4_prefix_length: 24
network_ipv4_gateway: "192.168.1.1"
network_dns_servers:
  - 192.168.1.1
  - 8.8.8.8
```

Notes:

- changing the hostname is usually safer than changing the IP address
- change IP addresses one host at a time
- after changing an IP address, update the matching host list in `.env`
- the `network` role backs up `50-cloud-init.yaml` to `50-cloud-init.yaml.ansible.bak` when the file exists, then uses the new Netplan configuration to replace the old one

## Docker Swarm

To run the Swarm role, the inventory needs manager and worker groups. With the
current dynamic inventory, define these groups with the `ANSIBLE_SWARM_*`
variables in `.env`. Static inventories can use a layout like this:

```ini
[swarm_managers]
192.168.1.151 docker_swarm_advertise_addr=192.168.1.151

[swarm_app_workers]
192.168.1.152 docker_swarm_advertise_addr=192.168.1.152
192.168.1.153 docker_swarm_advertise_addr=192.168.1.153
192.168.1.154 docker_swarm_advertise_addr=192.168.1.154

[swarm_data_workers]
192.168.1.155 docker_swarm_advertise_addr=192.168.1.155
192.168.1.156 docker_swarm_advertise_addr=192.168.1.156

[swarm_workers:children]
swarm_app_workers
swarm_data_workers
```

Common variables:

```yaml
docker_swarm_enabled: true
docker_swarm_manager_group: swarm_managers
docker_swarm_worker_group: swarm_workers
docker_swarm_listen_addr: "0.0.0.0:2377"
docker_swarm_port: 2377
docker_swarm_force_reset: false
docker_swarm_manager_addr: ""
docker_swarm_manage_iptables: true
docker_swarm_iptables_source_cidr: "0.0.0.0/0"
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

With `docker_swarm_manage_iptables: true`, the role opens the standard Swarm
iptables rules: `2377/tcp` on manager nodes, `7946/tcp`, `7946/udp`, and
`4789/udp` on all manager/worker nodes. Set
`docker_swarm_manage_encrypted_overlay_esp: true` to allow IP protocol `50`
(`esp`) when using encrypted overlay networks. Add published application ports
to `docker_swarm_service_ports`.

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

Set these values in `.env`:

```env
ANSIBLE_ZABBIX_AGENT_ENABLED=true
ANSIBLE_ZABBIX_SERVER_HOST=192.168.1.10
ANSIBLE_ZABBIX_AGENT_HOSTNAME=
```

`ANSIBLE_ZABBIX_SERVER_HOST` must be the IP address or DNS name of the control
machine as seen from target hosts. `ANSIBLE_ZABBIX_AGENT_HOSTNAME` is optional;
when it is empty, the role uses `inventory_hostname` so each target keeps a
unique agent hostname.

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

Run only Zabbix Agent configuration:

```bash
./scripts/run-ansible.sh deploy --tags zabbix
```

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
