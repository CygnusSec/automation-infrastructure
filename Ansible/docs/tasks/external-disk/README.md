# External Disk

This task creates one partition, formats it, mounts it, and persists the mount
in `/etc/fstab`.

This task can format disks. Check the target list and device name before
running it.

## What It Does

- checks `lsblk -f`
- validates that the configured disk exists
- refuses unexpected existing partition layouts
- creates a primary partition when configured
- formats the partition when no filesystem exists
- reads the partition UUID
- creates the mount point
- writes `/etc/fstab`
- runs `mount -a`
- verifies the mount with `findmnt`

## Key Variables

```env
ANSIBLE_EXTERNAL_DISK_ENABLED=true
ANSIBLE_EXTERNAL_DISK_TARGET_GROUP=external_disk_targets
# ANSIBLE_EXTERNAL_DISK_HOSTS="<disk-host-ip-1>,<disk-host-ip-2>"
ANSIBLE_EXTERNAL_DISK_DEVICE=/dev/sdb
ANSIBLE_EXTERNAL_DISK_PARTITION=/dev/sdb1
ANSIBLE_EXTERNAL_DISK_MOUNT_PATH=/mnt/data
ANSIBLE_EXTERNAL_DISK_FSTYPE=ext4
ANSIBLE_EXTERNAL_DISK_MOUNT_OPTS=defaults
ANSIBLE_EXTERNAL_DISK_CREATE_PARTITION=true
ANSIBLE_EXTERNAL_DISK_FORMAT=true
```

## Command

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags external_disk
```

Test on one host first:

```bash
./scripts/run-ansible.sh deploy --tags external_disk --limit <target-host-or-ip>
```

## Verification

```bash
lsblk -f
findmnt /mnt/data
cat /etc/fstab
```
