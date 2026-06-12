# docker_swarm

Initializes a Docker Swarm on the first manager and joins the remaining managers and workers.

Inventory example:

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

[linux:children]
swarm_managers
swarm_workers
```

Key variables:

```yaml
docker_swarm_enabled: true
docker_swarm_listen_addr: "0.0.0.0:2377"
docker_swarm_port: 2377
docker_swarm_force_reset: false
docker_swarm_manage_iptables: true
docker_swarm_iptables_source_cidr: "0.0.0.0/0"
docker_swarm_manage_encrypted_overlay_esp: false
docker_swarm_service_ports:
  - port: 80
    protocol: tcp
```

The role opens the standard Swarm rules with iptables:

- `2377/tcp` on manager nodes
- `7946/tcp` on all manager/worker nodes
- `7946/udp` on all manager/worker nodes
- `4789/udp` on all manager/worker nodes
- IP protocol `50` / `esp` on all nodes when `docker_swarm_manage_encrypted_overlay_esp: true`

Add published application ports to `docker_swarm_service_ports`.

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
192.168.1.152 docker_swarm_advertise_addr=192.168.1.152 docker_swarm_node_labels='{"rack":"rack-a"}'
```
