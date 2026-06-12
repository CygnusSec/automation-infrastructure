#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <environment-path> <terraform-command> [args...]"
  echo "Example: $0 envs/vcenter plan"
  exit 1
fi

ENV_PATH="$1"
shift

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_ENV_FILE="${ROOT_DIR}/.env.compose"
LEGACY_ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${COMPOSE_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${COMPOSE_ENV_FILE}"
  set +a
elif [[ -f "${LEGACY_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${LEGACY_ENV_FILE}"
  set +a
fi

COMPOSE_ENV_ARGS=()
if [[ -f "${COMPOSE_ENV_FILE}" ]]; then
  COMPOSE_ENV_ARGS=(--env-file "${COMPOSE_ENV_FILE}")
fi

DEFAULT_TF_IMAGE="terraform-vmware-vcenter-runtime:1.8.5"
TF_IMAGE="${TERRAFORM_IMAGE:-${DEFAULT_TF_IMAGE}}"
TF_CONFIG_FILE="${ROOT_DIR}/.terraformrc.offline"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

restore_env_ownership() {
  local env_dir="${ROOT_DIR}/${ENV_PATH}"

  if [[ -d "${env_dir}" ]] && docker image inspect "${TF_IMAGE}" >/dev/null 2>&1; then
    docker run --rm \
      --entrypoint chown \
      -v "${env_dir}:/workspace-env" \
      "${TF_IMAGE}" -R "${HOST_UID}:${HOST_GID}" /workspace-env >/dev/null 2>&1 || true
  fi
}

trap restore_env_ownership EXIT

if [[ ! -d "${ROOT_DIR}/${ENV_PATH}" ]]; then
  echo "Environment path not found: ${ROOT_DIR}/${ENV_PATH}"
  exit 1
fi

for arg in "$@"; do
  if [[ "${arg}" == -state=* ]]; then
    state_path="${arg#-state=}"
    state_dir="$(dirname "${state_path}")"
    if [[ "${state_dir}" != "." ]]; then
      mkdir -p "${ROOT_DIR}/${ENV_PATH}/${state_dir}"
    fi
  fi
done

mkdir -p "${ROOT_DIR}/.docker-cache/terraform"
mkdir -p "${ROOT_DIR}/providers"

if ! docker image inspect "${TF_IMAGE}" >/dev/null 2>&1; then
  TF_ENV="${ENV_PATH}" TERRAFORM_IMAGE="${TF_IMAGE}" docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${ROOT_DIR}/docker-compose.yml" build terraform
fi

if [[ -n "$(find "${ROOT_DIR}/providers" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
  cat > "${TF_CONFIG_FILE}" <<EOOFFLINE
provider_installation {
  filesystem_mirror {
    path    = "/workspace/providers"
    include = ["registry.terraform.io/*/*"]
  }

  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
EOOFFLINE

  TF_ENV="${ENV_PATH}" TERRAFORM_IMAGE="${TF_IMAGE}" docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${ROOT_DIR}/docker-compose.yml" run --rm \
    -e TF_CLI_CONFIG_FILE=/workspace/.terraformrc.offline terraform init -lockfile=readonly
  TF_ENV="${ENV_PATH}" TERRAFORM_IMAGE="${TF_IMAGE}" docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${ROOT_DIR}/docker-compose.yml" run --rm \
    -e TF_CLI_CONFIG_FILE=/workspace/.terraformrc.offline terraform "$@"
  exit 0
fi

TF_ENV="${ENV_PATH}" TERRAFORM_IMAGE="${TF_IMAGE}" docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${ROOT_DIR}/docker-compose.yml" run --rm terraform init
TF_ENV="${ENV_PATH}" TERRAFORM_IMAGE="${TF_IMAGE}" docker compose "${COMPOSE_ENV_ARGS[@]}" -f "${ROOT_DIR}/docker-compose.yml" run --rm terraform "$@"
