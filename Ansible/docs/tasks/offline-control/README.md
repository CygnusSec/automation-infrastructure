# Offline Control Prepare

This task prepares the offline Ansible control machine after extracting an
offline bundle.

## What It Does

- loads `../image-runtime/ansible-runtime.tar`
- creates `.env` from `.env.example` if `.env` does not exist
- sets offline runtime variables in `.env`
- pins `LOCAL_RUNTIME_IMAGE` to the packaged runtime image

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

## Expected Bundle Layout

```text
ansible-base-offline-<timestamp>/
  image-runtime/ansible-runtime.tar
  project/
```

