# Docker Swarm iptables

This task configures iptables rules for Swarm control, gossip, overlay, and
published service ports.

It is separated from the main Swarm task. Running `--tags docker_swarm` does not
run iptables management.

## Key Variables

```env
ANSIBLE_DOCKER_SWARM_MANAGE_IPTABLES=true
ANSIBLE_DOCKER_SWARM_IPTABLES_SOURCE_CIDR=<source-cidr>
ANSIBLE_DOCKER_SWARM_MANAGE_ENCRYPTED_OVERLAY_ESP=false
ANSIBLE_DOCKER_SWARM_SERVICE_PORTS="[]"
```

Example published service port list:

```env
ANSIBLE_DOCKER_SWARM_SERVICE_PORTS="[{published: 80, protocol: tcp}, {published: 443, protocol: tcp}]"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker_swarm_iptables
```

## Opened Ports

- `2377/tcp` on manager nodes
- `7946/tcp` on manager and worker nodes
- `7946/udp` on manager and worker nodes
- `4789/udp` on manager and worker nodes
- protocol `esp` when encrypted overlay support is enabled
