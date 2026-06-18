#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

if [[ ! -f "${ROOT_DIR}/inventories/customer-a/secrets/auth.yaml" ]]; then
  echo "Missing password secret: inventories/customer-a/secrets/auth.yaml" >&2
  echo "Create it from inventories/customer-a/secrets/auth.yaml.example and set ansible_password." >&2
  exit 1
fi

ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE=true \
ANSIBLE_SSH_COMMON_ARGS="-o PubkeyAuthentication=no -o PreferredAuthentications=password" \
  "${ROOT_DIR}/scripts/run-ansible.sh" ssh-copy-id "$@"

set_env_value() {
  local key="$1"
  local value="$2"
  local tmp_file
  tmp_file="$(mktemp)"

  if [[ -f "${ENV_FILE}" ]] && grep -q "^${key}=" "${ENV_FILE}"; then
    awk -v key="${key}" -v value="${value}" '
      BEGIN { prefix = key "=" }
      index($0, prefix) == 1 { print key "=" value; next }
      { print }
    ' "${ENV_FILE}" > "${tmp_file}"
    mv "${tmp_file}" "${ENV_FILE}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
    rm -f "${tmp_file}"
  fi
}

set_env_value "ANSIBLE_SSH_PASSWORD_AUTH" ""
set_env_value "ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE" ""
set_env_value "ANSIBLE_SSH_COMMON_ARGS" ""
set_env_value "ANSIBLE_PASSWORD" ""

echo "SSH key bootstrap completed."
echo "Updated .env to use private key authentication for subsequent runs."
echo "Private key: ${ANSIBLE_SSH_PRIVATE_KEY_FILE:-./inventories/customer-a/secrets/id_rsa}"
