# Offline Control Prepare

This task prepares the offline Ansible control machine after extracting an
offline bundle.

## What It Does

- loads `../image-runtime/ansible-runtime.tar`
- creates `.env` from `.env.example` if `.env` does not exist
- creates missing `env.d/[0-9][0-9]-*.env` files from their examples
- sets offline runtime variables in `.env`
- pins `LOCAL_RUNTIME_IMAGE` to the packaged runtime image
- leaves existing `.env` and `env.d/*.env` values in place except for the
  offline runtime variables it must set

## Command

Run from the extracted bundle project directory:

```bash
cd project
./scripts/prepare-offline-control.sh
```

Then validate:

```bash
./scripts/run-ansible.sh deploy --syntax-check
./scripts/run-ansible.sh predeploy-show-info
```

Review `.env` and `env.d/*.env` before running a real deployment. The offline
bundle intentionally does not include local env files or private SSH keys from
the online build machine.

## Expected Bundle Layout

```text
ansible-base-offline-<timestamp>/
  image-runtime/ansible-runtime.tar
  project/
```
