# Docker

This task installs Docker and Docker Compose v2 on Ubuntu targets.

## What It Does

- installs Docker packages from apt or a local `.deb` repository
- creates the `docker` group
- adds configured users to the `docker` group
- enables and starts the Docker service

## Key Variables

```env
ANSIBLE_DOCKER_INSTALL_FROM_LOCAL_REPO=true
ANSIBLE_DOCKER_REPO_SOURCE=./repo/docker
ANSIBLE_DOCKER_REPO_DEST=/media/installation/docker
```

The default package list is:

```yaml
docker_packages:
  - docker.io
  - docker-compose-v2
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags docker
```

## Offline Notes

When using the local repository mode, put Docker `.deb` packages under:

```text
Ansible/repo/docker/
```

## Verification

```bash
./scripts/run-ansible.sh deploy --tags docker --limit 172.16.3.21
```

Then SSH to the host and check:

```bash
docker version
docker compose version
```

