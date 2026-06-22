# Docker Swarm iptables

This task configures iptables rules for Swarm manager join traffic, node
discovery, and overlay networking. It builds peer IPs from the configured
`swarm_managers` and `swarm_workers` inventory groups and skips each node's own
IP, matching the behavior of the legacy `allow_swarm` shell function.

It is separated from the main Swarm task. Running `--tags docker_swarm` does not
run iptables management.

## Key Variables

```env
ANSIBLE_DOCKER_SWARM_MANAGE_IPTABLES=true
ANSIBLE_DOCKER_SWARM_MANAGE_ENCRYPTED_OVERLAY_ESP=false
```

Service source IPs and external service IP/port lists are handled by the
separate `iptables` task through `INPUT` and `OUTPUT` chains.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables
```

## Opened Traffic

- worker/client traffic to managers on `2377/tcp`
- manager/server traffic from nodes on `2377/tcp`
- bidirectional node discovery on `7946/tcp`
- bidirectional node discovery on `7946/udp`
- bidirectional overlay networking on `4789/udp`
- bidirectional protocol `esp` when encrypted overlay support is enabled
