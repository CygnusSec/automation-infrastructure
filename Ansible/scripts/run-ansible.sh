#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <playbook> [ansible-playbook-args...]"
  echo "Example: $0 deploy.yaml --tags docker"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

DEFAULT_ANSIBLE_IMAGE="ansible-base-runtime:local"
LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE:-${DEFAULT_ANSIBLE_IMAGE}}"
RUNTIME_IMAGE="${RUNTIME_IMAGE:-}"
ANSIBLE_CONTROL_OFFLINE="${ANSIBLE_CONTROL_OFFLINE:-false}"

if [[ -n "${RUNTIME_IMAGE}" ]]; then
  ANSIBLE_IMAGE="${RUNTIME_IMAGE}"
  USE_REGISTRY_IMAGE=1
else
  ANSIBLE_IMAGE="${LOCAL_RUNTIME_IMAGE}"
  USE_REGISTRY_IMAGE=0
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

restore_project_ownership() {
  if docker image inspect "${ANSIBLE_IMAGE}" >/dev/null 2>&1; then
    docker run --rm \
      --entrypoint chown \
      -v "${ROOT_DIR}:/workspace" \
      "${ANSIBLE_IMAGE}" -R "${HOST_UID}:${HOST_GID}" /workspace >/dev/null 2>&1 || true
  fi
}

trap restore_project_ownership EXIT

if [[ ! -f "${ROOT_DIR}/$1" ]]; then
  echo "Playbook not found: ${ROOT_DIR}/$1"
  exit 1
fi

INVENTORY_SECRET_VARS_RELATIVE="${ANSIBLE_INVENTORY_SECRET_VARS:-inventories/customer-a/secrets/auth.yaml}"
INVENTORY_SECRET_VARS="${ROOT_DIR}/${INVENTORY_SECRET_VARS_RELATIVE}"
EXTRA_ARGS=()

if [[ -f "${INVENTORY_SECRET_VARS}" ]]; then
  EXTRA_ARGS+=("-e" "@${INVENTORY_SECRET_VARS_RELATIVE}")
fi

if ! docker image inspect "${ANSIBLE_IMAGE}" >/dev/null 2>&1; then
  if [[ "${ANSIBLE_CONTROL_OFFLINE}" == "true" ]]; then
    echo "Ansible runtime image is not available locally: ${ANSIBLE_IMAGE}" >&2
    echo "Control machine is offline, so the wrapper will not pull/build images." >&2
    echo "Load the offline bundle image first: ./scripts/prepare-offline-control.sh" >&2
    exit 1
  fi

  if [[ "${USE_REGISTRY_IMAGE}" -eq 1 ]]; then
    docker pull "${ANSIBLE_IMAGE}"
  else
    RUNTIME_IMAGE="${ANSIBLE_IMAGE}" LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE}" \
      docker compose -f "${ROOT_DIR}/docker-compose.yaml" build ansible
  fi
fi

RUNTIME_IMAGE="${ANSIBLE_IMAGE}" LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE}" \
  docker compose -f "${ROOT_DIR}/docker-compose.yaml" run --rm ansible ansible-playbook "$1" "${EXTRA_ARGS[@]}" "${@:2}"
