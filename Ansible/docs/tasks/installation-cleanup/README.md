# Installation Cleanup

Cleans every item directly under `/media/installation` on target hosts and keeps
the `/media/installation` directory itself.

This task is tagged with `never`, so it does not run during a normal deploy.
Run it explicitly:

```bash
cd Ansible
./scripts/run-ansible.sh deploy --tags installation_cleanup
```

## Variables

Set these in `env.d/20-base.env`:

```env
ANSIBLE_INSTALLATION_CLEANUP_TARGET_GROUP=all_targets
ANSIBLE_INSTALLATION_CLEANUP_DIR=/media/installation
```

The cleanup directory is guarded and must be exactly `/media/installation`.
