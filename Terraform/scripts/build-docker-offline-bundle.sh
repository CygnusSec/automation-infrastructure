#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <environment-path>"
  echo "Example: $0 envs/vcenter"
  exit 1
fi

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

DIST_DIR="${ROOT_DIR}/offline-dist"
STAGE_DIR="${DIST_DIR}/terraform-vmware-vcenter-docker-offline"
PROJECT_DIR="${STAGE_DIR}/project"
PROVIDERS_DIR="${PROJECT_DIR}/providers"
ENV_PATH="$1"
DEFAULT_TERRAFORM_IMAGE="terraform-vmware-vcenter-runtime:1.8.5"
RUNTIME_IMAGE="${RUNTIME_IMAGE:-}"
LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE:-${TERRAFORM_IMAGE:-${DEFAULT_TERRAFORM_IMAGE}}}"
TERRAFORM_VERSION="${TERRAFORM_VERSION:-1.8.5}"
OFFLINE_PLATFORM="${OFFLINE_PLATFORM:-linux/amd64}"
TF_LOCK_PLATFORM="${OFFLINE_PLATFORM/\//_}"

case "${OFFLINE_PLATFORM}" in
  linux/amd64|linux/arm64) ;;
  *)
    echo "Unsupported OFFLINE_PLATFORM: ${OFFLINE_PLATFORM}. Use linux/amd64 or linux/arm64." >&2
    exit 1
    ;;
esac

if [[ -n "${RUNTIME_IMAGE}" ]]; then
  IMAGE_NAME="${RUNTIME_IMAGE}"
  USE_REGISTRY_IMAGE=1
else
  IMAGE_NAME="${LOCAL_RUNTIME_IMAGE}"
  USE_REGISTRY_IMAGE=0
fi

IMAGE_ARCHIVE="${STAGE_DIR}/terraform-image.tar"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

restore_project_ownership() {
  local path="$1"

  if [[ -d "${path}" ]] && docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    docker run --rm \
      --platform "${OFFLINE_PLATFORM}" \
      --entrypoint chown \
      -v "${path}:/workspace-stage" \
      "${IMAGE_NAME}" -R "${HOST_UID}:${HOST_GID}" /workspace-stage
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command not found"
  exit 1
fi

if [[ ! -d "${ROOT_DIR}/${ENV_PATH}" ]]; then
  echo "Environment path not found: ${ROOT_DIR}/${ENV_PATH}"
  exit 1
fi

if [[ "${USE_REGISTRY_IMAGE}" -eq 1 ]]; then
  docker pull --platform "${OFFLINE_PLATFORM}" "${IMAGE_NAME}"
else
  docker build --platform "${OFFLINE_PLATFORM}" -t "${IMAGE_NAME}" --build-arg TERRAFORM_VERSION="${TERRAFORM_VERSION}" -f "${ROOT_DIR}/docker/Dockerfile" "${ROOT_DIR}"
fi

docker run --rm --platform "${OFFLINE_PLATFORM}" "${IMAGE_NAME}" version >/dev/null

mkdir -p "${DIST_DIR}"
restore_project_ownership "${STAGE_DIR}"
rm -rf "${STAGE_DIR}"
mkdir -p "${PROJECT_DIR}"

cp -R "${ROOT_DIR}/envs" "${PROJECT_DIR}/envs"
cp -R "${ROOT_DIR}/modules" "${PROJECT_DIR}/modules"
cp -R "${ROOT_DIR}/scripts" "${PROJECT_DIR}/scripts"
cp -R "${ROOT_DIR}/docker" "${PROJECT_DIR}/docker"
cp -R "${ROOT_DIR}/docs" "${PROJECT_DIR}/docs"
cp "${ROOT_DIR}/README.md" "${PROJECT_DIR}/README.md"
cp "${ROOT_DIR}/docker-compose.yml" "${PROJECT_DIR}/docker-compose.yml"
cp "${ROOT_DIR}/.dockerignore" "${PROJECT_DIR}/.dockerignore"
cp "${ROOT_DIR}/.gitignore" "${PROJECT_DIR}/.gitignore"
cp "${ROOT_DIR}/.env.compose.example" "${PROJECT_DIR}/.env.compose.example"
cp "${ROOT_DIR}/.env.terraform.example" "${PROJECT_DIR}/.env.terraform.example"

find "${PROJECT_DIR}" -type f \( -name "*.tfstate" -o -name "*.tfstate.*" -o -name "*.tfvars" \) ! -name "*.example" -delete
find "${PROJECT_DIR}" -type d -name ".terraform" -prune -exec rm -rf {} +
find "${PROJECT_DIR}" -type d -name ".docker-cache" -prune -exec rm -rf {} +
rm -f "${PROJECT_DIR}/.terraformrc.offline" "${PROJECT_DIR}/.env" "${PROJECT_DIR}/.env.compose" "${PROJECT_DIR}/.env.terraform"
mkdir -p "${PROVIDERS_DIR}"

cat > "${PROJECT_DIR}/.env.compose" <<EOFENV
TERRAFORM_IMAGE=${IMAGE_NAME}
TERRAFORM_VERSION=${TERRAFORM_VERSION}
OFFLINE_PLATFORM=${OFFLINE_PLATFORM}
EOFENV

docker run --rm \
  --platform "${OFFLINE_PLATFORM}" \
  -v "${PROJECT_DIR}:/workspace" \
  -w "/workspace/${ENV_PATH}" \
  "${IMAGE_NAME}" init

docker run --rm \
  --platform "${OFFLINE_PLATFORM}" \
  -v "${PROJECT_DIR}:/workspace" \
  -w "/workspace/${ENV_PATH}" \
  "${IMAGE_NAME}" providers lock -platform="${TF_LOCK_PLATFORM}"

docker run --rm \
  --platform "${OFFLINE_PLATFORM}" \
  -v "${PROJECT_DIR}:/workspace" \
  -w "/workspace/${ENV_PATH}" \
  "${IMAGE_NAME}" providers mirror /workspace/providers

restore_project_ownership "${PROJECT_DIR}"
find "${PROJECT_DIR}" -type d -name ".terraform" -prune -exec rm -rf {} +
rm -f "${PROJECT_DIR}/.terraformrc.offline"

docker save -o "${IMAGE_ARCHIVE}" "${IMAGE_NAME}"

cat > "${STAGE_DIR}/load-and-run.sh" <<EOFSCRIPT
#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

docker load -i "\${ROOT_DIR}/terraform-image.tar"
echo "Docker image loaded: ${IMAGE_NAME}"
echo "Project path: \${ROOT_DIR}/project"
echo "Before planning, securely transfer .env.terraform, terraform.auto.tfvars,"
echo "the exact real group tfvars, and its matching state. Sanitized examples are"
echo "not compatible with production state addresses."
echo "Run example after that transfer:"
echo "  cd \${ROOT_DIR}/project"
echo "  ./scripts/run-terraform.sh envs/vcenter plan -var-file=vms/vms-tldh-17.tfvars -state=states/terraform-tldh-17.tfstate"
EOFSCRIPT

chmod +x "${STAGE_DIR}/load-and-run.sh"
chmod +x "${PROJECT_DIR}/scripts/run-terraform.sh"
chmod +x "${PROJECT_DIR}/scripts/build-docker-offline-bundle.sh"
chmod +x "${PROJECT_DIR}/scripts/check-tfvars-examples.sh"
tar -C "${DIST_DIR}" -czf "${DIST_DIR}/terraform-vmware-vcenter-docker-offline.tar.gz" "terraform-vmware-vcenter-docker-offline"

echo "Offline Docker bundle created: ${DIST_DIR}/terraform-vmware-vcenter-docker-offline.tar.gz"
