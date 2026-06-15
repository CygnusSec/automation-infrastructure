# Docker Swarm

This task initializes Docker Swarm on the first manager and joins workers.

## What It Does

- validates that a manager group exists
- initializes the primary manager
- reads manager and worker join tokens
- joins additional managers and workers
- applies Docker Swarm node labels by node ID

## Key Variables

```env
ANSIBLE_DOCKER_SWARM_ENABLED=true
ANSIBLE_DOCKER_SWARM_MANAGER_GROUP=swarm_managers
ANSIBLE_DOCKER_SWARM_WORKER_GROUP=swarm_workers
ANSIBLE_DOCKER_SWARM_LISTEN_ADDR=0.0.0.0:2377
ANSIBLE_DOCKER_SWARM_PORT=2377
ANSIBLE_DOCKER_SWARM_MANAGER_ADDR=172.16.5.57
ANSIBLE_DOCKER_SWARM_FORCE_RESET=false
ANSIBLE_DOCKER_SWARM_GROUP_LABELS="{}"
ANSIBLE_DOCKER_SWARM_NODE_LABELS="{}"
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker_swarm
```

## Reset And Rejoin

Use reset only when you intentionally want nodes to leave their current Swarm:

```env
ANSIBLE_DOCKER_SWARM_FORCE_RESET=true
```

Then run:

```bash
./scripts/run-ansible.sh deploy --tags docker_swarm
```

Set it back to `false` after the run.

## Verification

On the manager:

```bash
docker node ls
docker node inspect <node-id> --format '{{ json .Spec.Labels }}'
```

