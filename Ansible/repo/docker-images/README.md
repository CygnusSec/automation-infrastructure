# Offline Docker Images

Offline Docker service images are saved here when target hosts cannot pull
images from a registry.

Expected default files:

```text
bind9.tar
chrony.tar
```

The normal offline bundle flow creates these files automatically:

```bash
./scripts/build-offline-bundle.sh
```

The build script builds the images from:

```text
build/dns-server.Dockerfile
build/time-server.Dockerfile
```

Then run on the offline control machine:

```bash
./scripts/run-ansible.sh deploy --tags dns_time_services
```

The tar files are local artifacts and should not be committed.
