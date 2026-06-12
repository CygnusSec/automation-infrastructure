#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_IMAGE_TAR="${ROOT_DIR}/../image-runtime/ansible-runtime.tar"
IMAGE_TAR="${1:-${DEFAULT_IMAGE_TAR}}"
RUNTIME_IMAGE_FILE="$(dirname "${IMAGE_TAR}")/runtime-image.txt"
ENV_FILE="${ROOT_DIR}/.env"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"

if [[ ! -f "${IMAGE_TAR}" ]]; then
  echo "Runtime image tar not found: ${IMAGE_TAR}" >&2
  echo "Expected path when running from an offline bundle: ../image-runtime/ansible-runtime.tar" >&2
  exit 1
fi

if [[ ! -f "${RUNTIME_IMAGE_FILE}" ]]; then
  echo "Runtime image name file not found: ${RUNTIME_IMAGE_FILE}" >&2
  exit 1
fi

RUNTIME_IMAGE_NAME="$(tr -d '[:space:]' < "${RUNTIME_IMAGE_FILE}")"

if [[ -z "${RUNTIME_IMAGE_NAME}" ]]; then
  echo "Runtime image name is empty in ${RUNTIME_IMAGE_FILE}" >&2
  exit 1
fi

echo "Loading Ansible runtime image from ${IMAGE_TAR}"
docker load -i "${IMAGE_TAR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  else
    touch "${ENV_FILE}"
  fi
fi

set_env_value() {
  local key="$1"
  local value="$2"
  local tmp_file
  tmp_file="$(mktemp)"

  if grep -q "^${key}=" "${ENV_FILE}"; then
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

set_env_value "ANSIBLE_CONTROL_OFFLINE" "true"
set_env_value "LOCAL_RUNTIME_IMAGE" "${RUNTIME_IMAGE_NAME}"
set_env_value "RUNTIME_IMAGE" ""

echo "Offline control machine is prepared."
echo "Review ${ENV_FILE}, then run: ./scripts/run-ansible.sh deploy --syntax-check"
