# external_disk

Creates, formats, mounts, and persists an external disk mount.

This role can format disks. Verify `ANSIBLE_EXTERNAL_DISK_HOSTS` and
`ANSIBLE_EXTERNAL_DISK_DEVICE` before running it.

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags external_disk
```

Test one host first:

```bash
./scripts/run-ansible.sh deploy --tags external_disk --limit <target-host-or-ip>
```

## Key Variables

```env
ANSIBLE_EXTERNAL_DISK_ENABLED=true
ANSIBLE_EXTERNAL_DISK_TARGET_GROUP=external_disk_targets
ANSIBLE_EXTERNAL_DISK_DEVICE=/dev/sdb
ANSIBLE_EXTERNAL_DISK_PARTITION=/dev/sdb1
ANSIBLE_EXTERNAL_DISK_MOUNT_PATH=/mnt/data
ANSIBLE_EXTERNAL_DISK_FSTYPE=ext4
ANSIBLE_EXTERNAL_DISK_CREATE_PARTITION=true
ANSIBLE_EXTERNAL_DISK_FORMAT=true
```

## Task Runbook

See [External Disk](../../docs/tasks/external-disk/README.md).
