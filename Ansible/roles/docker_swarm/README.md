# docker_swarm

Initializes a Docker Swarm on the first manager and joins the remaining managers and workers.

## Commands

Initialize or converge Swarm:

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker_swarm
```

Leave Swarm:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_leave
```

Use the configured sudo-capable SSH user, not `root`. The wrapper connects as
`ANSIBLE_SSH_USER`; this role uses Ansible `become`/sudo for Docker commands.

Configure iptables separately:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables
```

Inventory example:

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

[linux:children]
swarm_managers
swarm_workers
```

Key variables:

```yaml
docker_swarm_enabled: true
docker_swarm_listen_addr: "<listen-ip>:2377"
docker_swarm_port: 2377
docker_swarm_force_reset: false
docker_swarm_leave_force: true
docker_swarm_manage_iptables: true
docker_swarm_manage_encrypted_overlay_esp: false
```

The iptables task builds peer IPs from `swarm_managers` and `swarm_workers`,
skips each node's own IP, and opens the Swarm rules used by the legacy
`allow_swarm` shell function:

- manager join traffic on `2377/tcp`
- node discovery on `7946/tcp` and `7946/udp`
- overlay networking on `4789/udp`
- IP protocol `50` / `esp` on all nodes when `docker_swarm_manage_encrypted_overlay_esp: true`

Service source IPs and external service IP/port lists are handled by the
separate `iptables` role through `INPUT` and `OUTPUT` chains.

Node labels can be applied by inventory group:

```yaml
docker_swarm_group_labels:
  swarm_app_workers:
    workload: app
    disk: ssd
  swarm_data_workers:
    workload: data
    disk: hdd
```

Override or add labels per host when needed:

```ini
[swarm_app_workers]
app-worker-01 ansible_host=<app-worker-ip-1> docker_swarm_advertise_addr=<app-worker-ip-1> docker_swarm_node_labels='{"rack":"rack-a"}'
```

## Task Runbooks

- [Docker Swarm](../../docs/tasks/docker-swarm/README.md)
- [Docker Swarm iptables](../../docs/tasks/docker-swarm-iptables/README.md)
