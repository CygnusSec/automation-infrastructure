# docker

Installs Docker and Docker Compose v2 on Ubuntu targets.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker
```

## Packages

By default it installs these packages:

```yaml
docker_packages:
  - docker.io
  - docker-compose-v2
```

The deploy play targets `ANSIBLE_DOCKER_TARGET_GROUP`, default `linux`, so Docker
installation stays scoped to swarm/Linux runtime hosts instead of every
`all_targets` host.

After adding local `.deb` files, switch to local installation:

```yaml
docker_install_from_local_repo: true
docker_repo_source: ./repo/docker
docker_repo_dest: /media/installation/docker
```

## Task Runbook

See [Docker](../../docs/tasks/docker/README.md).
