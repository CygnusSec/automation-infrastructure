# Ansible Guide

This repository prepares Ubuntu hosts and runs common operations tasks:

- install baseline packages
- configure sysctl, limits, and swap
- install Docker and Docker Compose v2
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

- inventory: `inventories/customer-a/hosts`
- shared variables: `inventories/customer-a/group_vars/all.yaml`
- secret: `inventories/customer-a/secrets/`
- main playbook: `deploy.yaml`
- quick host information playbook: `predeploy-show-info.yaml`
- Ansible runner script: `scripts/run-ansible.sh`
- script build bundle: `scripts/build-offline-bundle.sh`

## Inventory

Example:

```ini
[swarm_managers]
192.168.1.143 docker_swarm_advertise_addr=192.168.1.143

[swarm_workers]
#192.168.1.152 docker_swarm_advertise_addr=192.168.1.152

[linux:children]
swarm_managers
swarm_workers

[linux:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=./inventories/customer-a/secrets/id_rsa
ansible_become=true
ansible_become_method=sudo
```

Meaning:

- SSH connections use the key at `ansible_ssh_private_key_file`
- privilege escalation uses `sudo`
- if a host requires a `sudo` password, provide it through a secret file or `-K`

## Secret

Per-inventory secrets are stored under:

```text
inventories/customer-a/secrets/
```

Common files:

- SSH private key: `inventories/customer-a/secrets/id_rsa`
- optional sudo password: `inventories/customer-a/secrets/auth.yaml`

Example `auth.yaml`:

```yaml
ansible_become_password: "your-sudo-password"
```

`./scripts/run-ansible.sh` automatically loads `inventories/customer-a/secrets/auth.yaml` when the file exists.

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
- `hostname_*`
- `network_*`
- `docker_swarm_*`

Common environment variables:

```env
ANSIBLE_MANAGER_1_HOST=192.168.1.143
ANSIBLE_SSH_USER=ubuntu
ANSIBLE_SSH_PRIVATE_KEY_FILE=./inventories/customer-a/secrets/id_rsa
ANSIBLE_HOSTNAME_VALUE=ubuntu-proxmox-01-vm
ANSIBLE_NETWORK_INTERFACE=ens34
ANSIBLE_NETWORK_IPV4_ADDRESS=192.168.1.151
ANSIBLE_NETWORK_IPV4_GATEWAY=192.168.1.1
ANSIBLE_DOCKER_SWARM_ENABLED=true
```

For offline runs, prepare:

- `repo/prerequisite`
- `repo/docker`

## Validation Runs

Show quick host information:

```bash
./scripts/run-ansible.sh predeploy-show-info.yaml
```

Check syntax:

```bash
./scripts/run-ansible.sh deploy.yaml --syntax-check
```

Check syntax by tag:

```bash
./scripts/run-ansible.sh deploy.yaml --syntax-check --tags network
```

## Run By Tag

Run the full base play:

```bash
./scripts/run-ansible.sh deploy.yaml
```

Run only prerequisite:

```bash
./scripts/run-ansible.sh deploy.yaml --tags prerequisite
```

Run only Docker:

```bash
./scripts/run-ansible.sh deploy.yaml --tags docker
```

Change hostname:

```bash
./scripts/run-ansible.sh deploy.yaml --tags hostname --limit 192.168.1.143
```

Change IP:

```bash
./scripts/run-ansible.sh deploy.yaml --tags network --limit 192.168.1.143
```

Create or join Docker Swarm:

```bash
./scripts/run-ansible.sh deploy.yaml --tags docker_swarm
```

If you do not use `auth.yaml`, let Ansible prompt for the `sudo` password at runtime:

```bash
./scripts/run-ansible.sh deploy.yaml -K
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
- after changing an IP address, update `inventories/customer-a/hosts`
- the `network` role backs up `50-cloud-init.yaml` to `50-cloud-init.yaml.ansible.bak` when the file exists, then uses the new Netplan configuration to replace the old one

## Docker Swarm

To run the Swarm role, the inventory needs manager and worker groups. Example:

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

## Build Bundle Offline

```bash
./scripts/build-offline-bundle.sh
```

The bundle will be created in `dist/`.

## Common Errors

- SSH cannot connect to the host: check the inventory, firewall, user, and SSH key
- `sudo` fails: check `inventories/customer-a/secrets/auth.yaml` or rerun with `-K`
- offline repo is empty: the role fails because it cannot find `.deb` files
- IP address changed but inventory was not updated: later commands still point to the old IP address
- Swarm run without `swarm_managers` or `swarm_workers` groups in inventory: the Swarm play is skipped or has no matching hosts
