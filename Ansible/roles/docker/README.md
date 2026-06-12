# docker

Installs Docker on Ubuntu.

By default it installs packages from Ubuntu apt repositories:

```yaml
docker_packages:
  - docker.io
```

After adding local `.deb` files, switch to local installation:

```yaml
docker_install_from_local_repo: true
docker_repo_source: ./repo/docker
docker_repo_dest: /media/installation/docker
```
