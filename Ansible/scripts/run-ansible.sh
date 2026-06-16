#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

  echo "Usage: $0 <playbook> [ansible-playbook-args...]"
  echo "Examples:"
  echo "  $0 deploy --tags docker"
  echo "  $0 playbooks/deploy.yaml --tags docker"
  echo
  echo "Available playbooks:"
  find "${ROOT_DIR}/playbooks" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -exec basename {} \; 2>/dev/null | sort | sed 's/^/  - /'
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUESTED_PLAYBOOK="$1"

# shellcheck source=scripts/lib/env.sh
source "${ROOT_DIR}/scripts/lib/env.sh"
load_ansible_env "${ROOT_DIR}" "${@:2}"

DEFAULT_ANSIBLE_IMAGE="ansible-base-runtime:local"
LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE:-${DEFAULT_ANSIBLE_IMAGE}}"
RUNTIME_IMAGE="${RUNTIME_IMAGE:-}"
ANSIBLE_CONTROL_OFFLINE="${ANSIBLE_CONTROL_OFFLINE:-false}"
ANSIBLE_SSH_PASSWORD_AUTH="${ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE:-${ANSIBLE_SSH_PASSWORD_AUTH:-false}}"
export ANSIBLE_SSH_PASSWORD_AUTH

if [[ "${RUNTIME_IMAGE}" == *.tar || "${RUNTIME_IMAGE}" == *.tar.gz ]]; then
  echo "Ignoring RUNTIME_IMAGE tar path while running Ansible: ${RUNTIME_IMAGE}" >&2
  echo "Load runtime image tars with ./scripts/prepare-offline-control.sh, then use LOCAL_RUNTIME_IMAGE." >&2
  RUNTIME_IMAGE=""
fi

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

resolve_playbook() {
  local requested="$1"
  local candidate

  for candidate in \
    "${ROOT_DIR}/${requested}" \
    "${ROOT_DIR}/playbooks/${requested}" \
    "${ROOT_DIR}/playbooks/${requested}.yaml" \
    "${ROOT_DIR}/playbooks/${requested}.yml"; do
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate#${ROOT_DIR}/}"
      return 0
    fi
  done

  return 1
}

PLAYBOOK_PATH="$(resolve_playbook "${REQUESTED_PLAYBOOK}" || true)"

if [[ -z "${PLAYBOOK_PATH}" ]]; then
  echo "Playbook not found: ${REQUESTED_PLAYBOOK}" >&2
  echo "Looked in:" >&2
  echo "  ${ROOT_DIR}/${REQUESTED_PLAYBOOK}" >&2
  echo "  ${ROOT_DIR}/playbooks/${REQUESTED_PLAYBOOK}" >&2
  echo "  ${ROOT_DIR}/playbooks/${REQUESTED_PLAYBOOK}.yaml" >&2
  echo "  ${ROOT_DIR}/playbooks/${REQUESTED_PLAYBOOK}.yml" >&2
  exit 1
fi

INVENTORY_SECRET_VARS_RELATIVE="${ANSIBLE_INVENTORY_SECRET_VARS:-inventories/customer-a/secrets/auth.yaml}"
INVENTORY_SECRET_VARS="${ROOT_DIR}/${INVENTORY_SECRET_VARS_RELATIVE}"
EXTRA_ARGS=()
DOCKER_ENV_ARGS=(
  "-e" "ANSIBLE_SSH_PASSWORD_AUTH=${ANSIBLE_SSH_PASSWORD_AUTH}"
)

while IFS='=' read -r env_name _; do
  case "${env_name}" in
    ANSIBLE_*)
      DOCKER_ENV_ARGS+=("-e" "${env_name}=${!env_name}")
      ;;
  esac
done < <(env | sort)

# Set ANSIBLE_REMOTE_USER (Ansible built-in) so Ansible never falls back to
# the container's OS user (root) when group_vars somehow fail to apply.
if [[ -n "${ANSIBLE_SSH_USER:-}" ]]; then
  DOCKER_ENV_ARGS+=("-e" "ANSIBLE_REMOTE_USER=${ANSIBLE_SSH_USER}")
fi

if [[ "${ANSIBLE_SSH_PASSWORD_AUTH}" == "true" && -n "${ANSIBLE_SSH_COMMON_ARGS:-}" ]]; then
  DOCKER_ENV_ARGS+=("-e" "ANSIBLE_SSH_COMMON_ARGS=${ANSIBLE_SSH_COMMON_ARGS}")
fi

if [[ -f "${INVENTORY_SECRET_VARS}" ]]; then
  EXTRA_ARGS+=("-e" "@${INVENTORY_SECRET_VARS_RELATIVE}")
fi

if [[ -n "${ANSIBLE_PASSWORD:-}" ]]; then
  EXTRA_ARGS+=("-e" "ansible_password=${ANSIBLE_PASSWORD}")
fi

if [[ -n "${ANSIBLE_BECOME_PASSWORD:-}" ]]; then
  EXTRA_ARGS+=("-e" "ansible_become_password=${ANSIBLE_BECOME_PASSWORD}")
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
    ANSIBLE_IMAGE="${ANSIBLE_IMAGE}" LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE}" \
      docker compose -f "${ROOT_DIR}/docker-compose.yaml" build ansible
  fi
fi

# Pre-flight check: verify at least one inventory host variable is loaded.
# Any non-empty host var from 10-inventory.env proves the env was sourced.
_preflight_has_hosts="false"
for _pf_var in ANSIBLE_SWARM_MANAGER_HOSTS ANSIBLE_ALL_TARGET_HOSTS \
               ANSIBLE_ZABBIX_AGENT_HOSTS ANSIBLE_DNS_TIME_SERVER_HOSTS \
               ANSIBLE_EXTERNAL_DISK_HOSTS ANSIBLE_TLDH_DATABASE_MASTER_HOST; do
  if [[ -n "${!_pf_var:-}" ]]; then
    _preflight_has_hosts="true"
    break
  fi
done

if [[ "${_preflight_has_hosts}" == "false" ]]; then
  echo "" >&2
  echo "ERROR: All inventory host variables are empty." >&2
  echo "env.d/10-inventory.env was not loaded or contains no host definitions." >&2
  echo "Ansible will not find any hosts to target." >&2
  echo "" >&2
  echo "Troubleshooting:" >&2
  echo "  1. Verify env.d/10-inventory.env exists and contains host definitions" >&2
  echo "  2. Run: source scripts/lib/env.sh && load_ansible_env \"\$(pwd)\" && echo \"\${ANSIBLE_SWARM_MANAGER_HOSTS}\"" >&2
  echo "  3. On the server, check file permissions: ls -la env.d/10-inventory.env" >&2
  echo "" >&2
  exit 1
fi

ANSIBLE_IMAGE="${ANSIBLE_IMAGE}" LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE}" \
  docker compose -f "${ROOT_DIR}/docker-compose.yaml" run --rm "${DOCKER_ENV_ARGS[@]}" ansible ansible-playbook "${PLAYBOOK_PATH}" "${EXTRA_ARGS[@]}" "${@:2}"
