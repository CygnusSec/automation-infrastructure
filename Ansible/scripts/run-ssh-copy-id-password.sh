#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/inventories/customer-a/secrets/auth.yaml" ]]; then
  echo "Missing password secret: inventories/customer-a/secrets/auth.yaml" >&2
  echo "Create it from inventories/customer-a/secrets/auth.yaml.example and set ansible_password." >&2
  exit 1
fi

ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE=true \
ANSIBLE_SSH_COMMON_ARGS="-o PubkeyAuthentication=no -o PreferredAuthentications=password" \
  "${ROOT_DIR}/scripts/run-ansible.sh" ssh-copy-id "$@"
