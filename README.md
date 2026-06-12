# Automation Infrastructure

This project contains infrastructure automation for provisioning and configuring
Ubuntu-based environments.

It is split into two independent stacks:

- `Terraform/` provisions VMware vCenter virtual machines.
- `Ansible/` prepares Ubuntu hosts and configures runtime services such as
  Docker, Docker Swarm, Zabbix Agent, hostname, network settings, and base OS
  prerequisites.

The usual workflow is:

```text
Terraform creates VMs
  -> cloud-init prepares first boot access
  -> Ansible connects over SSH
  -> Ansible installs packages and configures services
```

## Repository Layout

```text
Terraform/   vCenter VM provisioning with Terraform
Ansible/     Ubuntu host configuration with Ansible
```

Each stack has its own Docker-based runtime, environment examples, scripts, and
README:

```text
Terraform/README.md
Ansible/README.md
```

Use the root README as the process overview. Use each stack README for detailed
variables, examples, and commands.

## How It Works

Terraform is responsible for infrastructure creation. It talks to vCenter,
clones VMs from templates, and passes cloud-init metadata/user data through
VMware `guestinfo`. VM definitions live in Terraform variable files.

Ansible is responsible for configuration after the machines exist. It uses SSH
to connect to the target hosts and applies roles for:

- OS prerequisites
- Docker and Docker Compose
- Docker Swarm init/join, node labels, and iptables rules
- Zabbix Agent pointing back to the control machine as the Zabbix server
- hostname and static network configuration

Both stacks are designed to run through Docker wrappers so the control machine
does not need local Terraform or Ansible installed.

## Prerequisites

Control machine:

- Docker Engine
- Docker Compose plugin
- network access to vCenter for Terraform
- SSH access to target hosts for Ansible

vCenter:

- account with permission to create/update/delete VMs
- datacenter, cluster or ESXi host, datastore, network/port group
- Ubuntu template with `cloud-init` and `open-vm-tools`

Target hosts:

- supported Ubuntu release
- SSH user with `sudo`
- package repository access, or local `.deb` files for offline installs

## Process

### 1. Provision VMs

Enter the Terraform stack:

```bash
cd Terraform
```

Create local configuration from examples:

```bash
cp .env.compose.example .env.compose
cp .env.terraform.example .env.terraform
cp envs/vcenter/terraform.auto.tfvars.example envs/vcenter/terraform.auto.tfvars
cp envs/vcenter/vms.auto.tfvars.example envs/vcenter/vms.auto.tfvars
```

Edit the vCenter connection, template, network, datastore, and VM definitions.
Then run Terraform through the wrapper:

```bash
./scripts/run-terraform.sh envs/vcenter validate
./scripts/run-terraform.sh envs/vcenter plan
./scripts/run-terraform.sh envs/vcenter apply
```

See `Terraform/README.md` for all VM fields and offline bundle instructions.

For larger environments, keep one vCenter environment and split VM groups by
`-var-file` and `-state`. Example:

```text
Terraform/envs/vcenter/
  vms/vms-tldh-17.tfvars
  states/terraform-tldh-17.tfstate
```

Run one group with:

```bash
./scripts/run-terraform.sh envs/vcenter plan -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
./scripts/run-terraform.sh envs/vcenter apply -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate
```

### 2. Configure Hosts

Enter the Ansible stack:

```bash
cd ../Ansible
```

Create local environment configuration:

```bash
cp .env.example .env
```

Edit `.env` for:

- target host IPs
- SSH user and private key path
- hostname and network settings
- Docker Swarm manager/worker settings
- Zabbix server host and agent hostname settings

Place secrets under:

```text
Ansible/inventories/customer-a/secrets/
```

Common files:

```text
id_rsa       SSH private key
auth.yaml    optional sudo password
```

Validate and run:

```bash
./scripts/run-ansible.sh deploy --syntax-check
./scripts/run-ansible.sh predeploy-show-info
./scripts/run-ansible.sh deploy
```

Run individual areas when needed:

```bash
./scripts/run-ansible.sh deploy --tags prerequisite
./scripts/run-ansible.sh deploy --tags docker
./scripts/run-ansible.sh deploy --tags zabbix
./scripts/run-ansible.sh deploy --tags docker_swarm
./scripts/run-ansible.sh deploy --tags hostname --limit <host>
./scripts/run-ansible.sh deploy --tags network --limit <host>
```

See `Ansible/README.md` for all variables, online/offline modes, and role
details.

## Online Mode

Online mode assumes the control machine can reach registries and package
repositories.

Terraform can pull/build its runtime image and download providers as needed.
Ansible can build its runtime image from `build/dockerfile`, and target hosts
can install packages from apt repositories when local repo mode is disabled.

Typical online flow:

```bash
cd Terraform
./scripts/run-terraform.sh envs/vcenter plan
./scripts/run-terraform.sh envs/vcenter apply

cd ../Ansible
./scripts/run-ansible.sh deploy
```

## Offline Mode

Offline mode is for a control machine without internet access. Build the offline
bundle on a machine that has network access, then copy it to the offline control
machine.

Terraform and Ansible each have their own offline bundle process. Use the stack
README for exact details:

```text
Terraform/README.md
Ansible/README.md
```

For Ansible, prepare the offline bundle on an online machine:

```bash
cd Ansible
cp .env.example .env
./scripts/build-offline-bundle.sh
```

Copy `dist/ansible-base-offline-*.tar.gz` to the offline control machine,
extract it, then run:

```bash
cd project
./scripts/prepare-offline-control.sh
```

Before running Ansible offline, make sure:

- Docker Engine and Docker Compose plugin are already installed on the control
  machine
- the packaged Ansible runtime image has been loaded
- SSH keys and optional sudo secret are present
- local `.deb` payloads exist under `Ansible/repo/` when target hosts cannot use
  apt repositories

Relevant Ansible repo directories:

```text
Ansible/repo/prerequisite/
Ansible/repo/docker/
Ansible/repo/zabbix/
```

## Safety Notes

- Keep local `.env`, `.env.compose`, `.env.terraform`, secrets, state files, and
  package payloads out of git.
- Change hostnames and static IP addresses with `--limit` one host at a time.
- For Docker Swarm, define manager and worker groups before running the Swarm
  role.
- For Zabbix Agent, set `ANSIBLE_ZABBIX_SERVER_HOST` to the control machine IP
  or DNS name reachable from target hosts.
- Review `terraform plan` before applying infrastructure changes.
