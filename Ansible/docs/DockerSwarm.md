# Docker Swarm Role Guide

This document describes how to extend the project to create a Docker Swarm cluster
after the hosts have Docker installed by the `docker` role.

## Goal

Target flow:

```text
prerequisite
  -> prepare the OS

docker
  -> install Docker, Docker Compose, and add the user to the docker group

docker_swarm
  -> initialize the first manager
  -> get join tokens
  -> join the remaining workers/managers to the cluster
```

The `docker_swarm` role must run after the `docker` role.

## Inventory

Split Swarm nodes into two groups:

```ini
[swarm_managers]
192.168.1.143

[swarm_workers]
192.168.1.144

[linux:children]
swarm_managers
swarm_workers

[linux:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=./inventories/customer-a/secrets/id_ed25519
ansible_become=true
ansible_become_method=sudo
```

Meaning:

```text
swarm_managers
  cluster manager nodes

swarm_workers
  cluster worker nodes

linux
  parent group so deploy.yaml can still run with hosts: linux
```

For production, use an odd number of managers:

```text
1 manager  -> lab/small setup
3 managers -> basic production setup
5 managers -> larger production setup
```

## Variables

Add to:

```text
inventories/customer-a/group_vars/all.yaml
```

Example:

```yaml
docker_swarm_enabled: true
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

If each host needs an advertise IP different from `inventory_hostname`, define it
per host in the inventory:

```ini
[swarm_managers]
manager-1 ansible_host=192.168.1.143 docker_swarm_advertise_addr=192.168.1.143

[swarm_workers]
worker-1 ansible_host=192.168.1.144 docker_swarm_advertise_addr=192.168.1.144
```

If `docker_swarm_advertise_addr` is not defined, the role can fall back to:

```yaml
ansible_host | default(inventory_hostname)
```

If `docker_swarm_manager_addr` is empty, the role automatically uses the primary
manager address in this order:

```text
docker_swarm_advertise_addr
ansible_host
inventory_hostname
```

## Create The Role

Create this structure:

```text
roles/docker_swarm/
  tasks/
    main.yml
  README.md
```

File:

```text
roles/docker_swarm/tasks/main.yml
```

Sample content for one primary manager and multiple workers:

```yaml
---
- name: Validate Docker Swarm inventory groups
  ansible.builtin.assert:
    that:
      - groups['swarm_managers'] is defined
      - groups['swarm_managers'] | length > 0
    fail_msg: "Define at least one host in [swarm_managers]."
  run_once: true
  tags:
    - docker_swarm

- name: Check Docker Swarm state
  ansible.builtin.command: docker info --format '{{ "{{" }} .Swarm.LocalNodeState {{ "}}" }}'
  register: docker_swarm_state
  changed_when: false
  failed_when: false
  tags:
    - docker_swarm

- name: Initialize Docker Swarm on first manager
  ansible.builtin.command: >
    docker swarm init
    --advertise-addr {{ docker_swarm_advertise_addr | default(ansible_host | default(inventory_hostname)) }}
    --listen-addr {{ docker_swarm_listen_addr | default('0.0.0.0:2377') }}
  when:
    - docker_swarm_enabled | default(true) | bool
    - inventory_hostname == groups['swarm_managers'][0]
    - docker_swarm_state.stdout != "active"
  tags:
    - docker_swarm

- name: Get Docker Swarm worker join token
  ansible.builtin.command: docker swarm join-token -q worker
  register: docker_swarm_worker_token
  changed_when: false
  delegate_to: "{{ groups['swarm_managers'][0] }}"
  run_once: true
  tags:
    - docker_swarm

- name: Join Docker Swarm as worker
  ansible.builtin.command: >
    docker swarm join
    --token {{ docker_swarm_worker_token.stdout }}
    {{ hostvars[groups['swarm_managers'][0]].docker_swarm_advertise_addr
       | default(hostvars[groups['swarm_managers'][0]].ansible_host
       | default(groups['swarm_managers'][0])) }}:{{ docker_swarm_port | default(2377) }}
  when:
    - docker_swarm_enabled | default(true) | bool
    - groups['swarm_workers'] is defined
    - inventory_hostname in groups['swarm_workers']
    - docker_swarm_state.stdout != "active"
  tags:
    - docker_swarm
```

## Multiple Managers

If you need multiple managers, add a task to get the manager token:

```yaml
- name: Get Docker Swarm manager join token
  ansible.builtin.command: docker swarm join-token -q manager
  register: docker_swarm_manager_token
  changed_when: false
  delegate_to: "{{ groups['swarm_managers'][0] }}"
  run_once: true
  tags:
    - docker_swarm

- name: Join Docker Swarm as additional manager
  ansible.builtin.command: >
    docker swarm join
    --token {{ docker_swarm_manager_token.stdout }}
    {{ hostvars[groups['swarm_managers'][0]].docker_swarm_advertise_addr
       | default(hostvars[groups['swarm_managers'][0]].ansible_host
       | default(groups['swarm_managers'][0])) }}:{{ docker_swarm_port | default(2377) }}
  when:
    - docker_swarm_enabled | default(true) | bool
    - inventory_hostname in groups['swarm_managers']
    - inventory_hostname != groups['swarm_managers'][0]
    - docker_swarm_state.stdout != "active"
  tags:
    - docker_swarm
```

## Update deploy.yaml

Add the `docker_swarm` role after the `docker` role:

```yaml
---
- name: Prepare base Ubuntu hosts
  hosts: linux
  gather_facts: false
  become: true
  pre_tasks:
    - name: Gather facts
      ansible.builtin.setup:
      tags:
        - always
  roles:
    - prerequisite
    - docker
    - docker_swarm
  tags:
    - base
```

Run only the Swarm role:

```bash
./scripts/run-ansible.sh deploy.yaml --tags docker_swarm
```

Run everything:

```bash
./scripts/run-ansible.sh deploy.yaml
```

## Required Open Ports

Swarm nodes must be able to connect to each other through:

```text
2377/tcp   cluster management
7946/tcp   node communication
7946/udp   node communication
4789/udp   overlay network traffic
esp        encrypted overlay traffic, IP protocol 50
```

If firewall/UFW is enabled, open the ports above. For lab environments, you can disable UFW:

```yaml
prerequisite_disable_ufw: true
```

Production should open the required ports instead of disabling the firewall entirely.

The role can create the required iptables rules automatically:

```yaml
docker_swarm_manage_iptables: true
docker_swarm_iptables_source_cidr: "0.0.0.0/0"
docker_swarm_manage_encrypted_overlay_esp: false
```

The role opens `2377/tcp` only on manager nodes. It opens `7946/tcp`,
`7946/udp`, and `4789/udp` on all manager/worker nodes. Enable
`docker_swarm_manage_encrypted_overlay_esp` only when using encrypted overlay
networks with `--opt encrypted`.

Published application ports are not predictable from the Swarm role. Add them
explicitly:

```yaml
docker_swarm_service_ports:
  - port: 80
    protocol: tcp
  - port: 443
    protocol: tcp
```

## Verify After Creating The Cluster

Check nodes:

```bash
RUNTIME_IMAGE=ansible-base-runtime:local LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local \
  docker compose -f docker-compose.yaml run --rm ansible \
  ansible swarm_managers -m command -a 'docker node ls'
```

Check Swarm state on each host:

```bash
RUNTIME_IMAGE=ansible-base-runtime:local LOCAL_RUNTIME_IMAGE=ansible-base-runtime:local \
  docker compose -f docker-compose.yaml run --rm ansible \
  ansible linux -m command -a "docker info --format '{{.Swarm.LocalNodeState}}'"
```

Expected:

```text
active
```

## Reset Swarm

Resetting Swarm is destructive. Do not run it automatically without a clear guard
variable.

Example variable:

```yaml
docker_swarm_force_reset: false
```

Reset task if it is truly needed:

```yaml
- name: Leave Docker Swarm
  ansible.builtin.command: docker swarm leave --force
  when: docker_swarm_force_reset | default(false) | bool
  tags:
    - docker_swarm_reset
```

Run only when explicitly requested:

```bash
./scripts/run-ansible.sh deploy.yaml --tags docker_swarm_reset
```

## Notes

- The Swarm role needs the Docker service to be running first.
- `--advertise-addr` must be an IP address that other nodes can reach.
- If the server has multiple NICs, define `docker_swarm_advertise_addr` per
  host.
- Workers join managers through port `2377/tcp`.
- Overlay networks need `7946/tcp`, `7946/udp`, and `4789/udp`.
- Do not use `docker swarm leave --force` in the normal deploy flow.
