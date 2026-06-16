# Base Preparation

This task runs the `prerequisite` and `docker` roles together against the
`linux` inventory group.

## What It Does

- validates Ubuntu target OS
- installs prerequisite packages
- configures sysctl and limits
- optionally disables swap, disables UFW, and sets timezone
- installs Docker and Docker Compose v2
- adds the Ansible SSH user to the `docker` group
- enables and starts Docker

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags base
```

Run only on one host while testing:

```bash
./scripts/run-ansible.sh deploy --tags base --limit <target-host-or-ip>
```

## Related Runbooks

- [Prerequisite](../prerequisite/README.md)
- [Docker](../docker/README.md)
