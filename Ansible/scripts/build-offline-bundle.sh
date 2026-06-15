#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BUNDLE_NAME="ansible-base-offline-${TIMESTAMP}"
BUNDLE_DIR="${DIST_DIR}/${BUNDLE_NAME}"
PROJECT_DIR="${BUNDLE_DIR}/project"
IMAGE_DIR="${BUNDLE_DIR}/image-runtime"
IMAGE_TAR="${IMAGE_DIR}/ansible-runtime.tar"

ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

RUNTIME_IMAGE="${RUNTIME_IMAGE:-}"
LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE:-ansible-base-runtime:local}"
ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES="${ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES:-true}"
ANSIBLE_DNS_SERVER_IMAGE="${ANSIBLE_DNS_SERVER_IMAGE:-local/bind9:offline}"
ANSIBLE_DNS_SERVER_IMAGE_TAR="${ANSIBLE_DNS_SERVER_IMAGE_TAR:-./repo/docker-images/bind9.tar}"
ANSIBLE_TIME_SERVER_IMAGE="${ANSIBLE_TIME_SERVER_IMAGE:-local/chrony:offline}"
ANSIBLE_TIME_SERVER_IMAGE_TAR="${ANSIBLE_TIME_SERVER_IMAGE_TAR:-./repo/docker-images/chrony.tar}"

if [[ "${RUNTIME_IMAGE}" == *.tar || "${RUNTIME_IMAGE}" == *.tar.gz ]]; then
  echo "Ignoring RUNTIME_IMAGE tar path while building bundle: ${RUNTIME_IMAGE}"
  RUNTIME_IMAGE=""
fi

project_path() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s/%s\n' "${ROOT_DIR}" "${path#./}"
  fi
}

if [[ -n "${RUNTIME_IMAGE}" ]]; then
  PACKAGE_IMAGE="${RUNTIME_IMAGE}"
  echo "Pulling runtime image: ${PACKAGE_IMAGE}"
  docker pull "${PACKAGE_IMAGE}"
else
  PACKAGE_IMAGE="${LOCAL_RUNTIME_IMAGE}"
  echo "Building runtime image from build/dockerfile: ${PACKAGE_IMAGE}"
  docker build -f "${ROOT_DIR}/build/dockerfile" -t "${PACKAGE_IMAGE}" "${ROOT_DIR}"
fi

if ! docker image inspect "${PACKAGE_IMAGE}" >/dev/null 2>&1; then
  echo "Runtime image is not available locally after pull/build: ${PACKAGE_IMAGE}" >&2
  exit 1
fi

build_service_image() {
  local name="$1"
  local dockerfile="$2"
  local image="$3"
  local tar_path="$4"

  echo "Building ${name} service image: ${image}"
  docker build -f "${ROOT_DIR}/${dockerfile}" -t "${image}" "${ROOT_DIR}"

  mkdir -p "$(dirname "${tar_path}")"
  echo "Saving ${name} service image: ${tar_path}"
  docker save "${image}" -o "${tar_path}"
}

if [[ "${ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES}" == "true" ]]; then
  build_service_image \
    "DNS" \
    "build/dns-server.Dockerfile" \
    "${ANSIBLE_DNS_SERVER_IMAGE}" \
    "$(project_path "${ANSIBLE_DNS_SERVER_IMAGE_TAR}")"

  build_service_image \
    "time" \
    "build/time-server.Dockerfile" \
    "${ANSIBLE_TIME_SERVER_IMAGE}" \
    "$(project_path "${ANSIBLE_TIME_SERVER_IMAGE_TAR}")"
fi

rm -rf "${BUNDLE_DIR}"
mkdir -p "${PROJECT_DIR}" "${IMAGE_DIR}"

echo "Saving runtime image: ${PACKAGE_IMAGE}"
docker save "${PACKAGE_IMAGE}" -o "${IMAGE_TAR}"

cat > "${IMAGE_DIR}/load-image.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAR="${1:-${SCRIPT_DIR}/ansible-runtime.tar}"

if [[ ! -f "${IMAGE_TAR}" ]]; then
  echo "Image tar not found: ${IMAGE_TAR}" >&2
  exit 1
fi

docker load -i "${IMAGE_TAR}"

echo "Runtime image loaded."
EOF
chmod +x "${IMAGE_DIR}/load-image.sh"

echo "Copying project files..."
tar \
  --exclude='.git' \
  --exclude='.codex' \
  --exclude='dist' \
  -C "${ROOT_DIR}" \
  -cf - \
  . | tar -C "${PROJECT_DIR}" -xf -

mkdir -p "${PROJECT_DIR}/inventories/customer-a/secrets"
touch "${PROJECT_DIR}/inventories/customer-a/secrets/.gitkeep"

echo "${PACKAGE_IMAGE}" > "${IMAGE_DIR}/runtime-image.txt"

cat > "${BUNDLE_DIR}/README-offline-control.md" <<EOF
# Offline Ansible Control Machine

This bundle is for a control machine without internet access.

Prerequisites on the offline control machine:

- Docker Engine
- Docker Compose plugin
- network access to the target hosts over SSH

Prepare the control machine:

\`\`\`bash
cd project
./scripts/prepare-offline-control.sh
\`\`\`

Edit \`project/.env\` for the target hosts and SSH settings, then run:

\`\`\`bash
./scripts/run-ansible.sh deploy --syntax-check
./scripts/run-ansible.sh deploy
\`\`\`

Dockerized DNS/time service images are packaged under:

\`\`\`text
project/repo/docker-images/bind9.tar
project/repo/docker-images/chrony.tar
\`\`\`

Run only those services with:

\`\`\`bash
./scripts/run-ansible.sh deploy --tags dns_time_services
\`\`\`

The runtime image packaged in this bundle is:

\`\`\`text
${PACKAGE_IMAGE}
\`\`\`
EOF

tar -C "${DIST_DIR}" -czf "${DIST_DIR}/${BUNDLE_NAME}.tar.gz" "${BUNDLE_NAME}"

echo "Bundle directory: ${BUNDLE_DIR}"
echo "Bundle archive: ${DIST_DIR}/${BUNDLE_NAME}.tar.gz"
