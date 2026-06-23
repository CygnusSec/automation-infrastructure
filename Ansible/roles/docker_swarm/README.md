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

Run Docker Swarm iptables sub-tasks separately:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_nodes
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_in
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_allow_connect_out
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables_docker_user_drop
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
docker_swarm_manage_encrypted_overlay_esp: true
docker_swarm_service_allowed_source_ips:
  - 172.16.3.98
  - 172.16.3.99
docker_swarm_service_host_interface: ens18
docker_swarm_service_bridge_interface: docker_gwbridge
docker_swarm_service_ports:
  - 80
docker_swarm_service_ports_by_host:
  172.16.3.21:
    - 80
    - 6380
  172.16.3.24:
    - 1070
docker_swarm_external_service_rules:
  - name: database
    ips:
      - 172.16.4.11
      - 172.16.4.12
    ports:
      - 3306
docker_swarm_external_service_rules_by_host:
  172.16.3.24:
    - name: storage
      ips:
        - 172.16.4.13
        - 172.16.4.14
      ports:
        - 9000
docker_swarm_logger_node_tag: logger
docker_swarm_logger_port: 514
docker_swarm_logger_protocols:
  - tcp
  - udp
```

The iptables task builds peer IPs from `swarm_managers` and `swarm_workers`,
skips each node's own IP, and opens the Swarm rules used by the legacy
`allow_swarm` shell function:

- manager join traffic on `2377/tcp`
- node discovery on `7946/tcp` and `7946/udp`
- overlay networking on `4789/udp`
- IP protocol `50` / `esp` on all nodes when `docker_swarm_manage_encrypted_overlay_esp: true`

Service source IPs for published Swarm services and Swarm container access to
external services are handled by this role in `DOCKER-USER`, between the host
interface and `docker_gwbridge`.
`docker_swarm_service_ports_by_host` overrides `docker_swarm_service_ports` on
matching node IPs.
`docker_swarm_external_service_rules_by_host` overrides
`docker_swarm_external_service_rules` on matching node IPs.
Nodes with `docker_swarm_node_labels.node_tag: logger` allow every Swarm node
IP to connect to `docker_swarm_logger_port`, default `514/tcp` and `514/udp`.
Every Swarm node also gets `DOCKER-USER` rules that allow Swarm container
traffic to reach logger node IPs on `docker_swarm_logger_port`.
When `docker_swarm_docker_user_drop_enabled: true`, the role appends
`iptables -A DOCKER-USER -j DROP` after allow rules and removes Docker's
default `iptables -D DOCKER-USER -j RETURN` first.

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
