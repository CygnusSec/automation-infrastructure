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

# shellcheck source=scripts/lib/env.sh
source "${ROOT_DIR}/scripts/lib/env.sh"
ANSIBLE_ENV_CONTEXT=offline_bundle load_ansible_env "${ROOT_DIR}"

RUNTIME_IMAGE="${RUNTIME_IMAGE:-}"
LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE:-ansible-base-runtime:local}"
ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES="${ANSIBLE_DNS_TIME_SERVICES_BUILD_IMAGES:-true}"
ANSIBLE_OFFLINE_BUNDLE_INCLUDE_REAL_ENV="${ANSIBLE_OFFLINE_BUNDLE_INCLUDE_REAL_ENV:-true}"
ANSIBLE_DNS_SERVER_IMAGE="${ANSIBLE_DNS_SERVER_IMAGE:-local/bind9:offline}"
ANSIBLE_DNS_SERVER_IMAGE_TAR="${ANSIBLE_DNS_SERVER_IMAGE_TAR:-./repo/docker-images/bind9.tar}"
ANSIBLE_TIME_SERVER_IMAGE="${ANSIBLE_TIME_SERVER_IMAGE:-local/chrony:offline}"
ANSIBLE_TIME_SERVER_IMAGE_TAR="${ANSIBLE_TIME_SERVER_IMAGE_TAR:-./repo/docker-images/chrony.tar}"
ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES="${ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES:-true}"
ANSIBLE_PREREQUISITE_DOWNLOAD_IMAGE="${ANSIBLE_PREREQUISITE_DOWNLOAD_IMAGE:-ubuntu:24.04}"
ANSIBLE_PREREQUISITE_REPO_SOURCE="${ANSIBLE_PREREQUISITE_REPO_SOURCE:-./repo/prerequisite}"
ANSIBLE_PREREQUISITE_OFFLINE_PACKAGES="${ANSIBLE_PREREQUISITE_OFFLINE_PACKAGES:-apt-transport-https ca-certificates curl gnupg ipset ipset-persistent iptables-persistent lsb-release net-tools netfilter-persistent openssh-client python3 python3-apt python3-pip rsync sshpass telnet traceroute unzip vim wget}"
ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE="${ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE:-./repo/update}"
ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES="${ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES:-libssl3t64 openssl inetutils-telnet telnet vim vim-common vim-runtime vim-tiny xxd}"
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES="${ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES:-true}"
ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE="${ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE:-ubuntu:24.04}"
ANSIBLE_ZABBIX_AGENT_REPO_SOURCE="${ANSIBLE_ZABBIX_AGENT_REPO_SOURCE:-./repo/zabbix}"
ANSIBLE_ZABBIX_AGENT_RELEASE_URL="${ANSIBLE_ZABBIX_AGENT_RELEASE_URL:-https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb}"
ANSIBLE_ZABBIX_AGENT_OFFLINE_PACKAGES="${ANSIBLE_ZABBIX_AGENT_OFFLINE_PACKAGES:-zabbix-agent2}"
ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES="${ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES:-true}"
ANSIBLE_ZABBIX_SERVER_REPO_SOURCE="${ANSIBLE_ZABBIX_SERVER_REPO_SOURCE:-./repo/zabbix-server}"
ANSIBLE_ZABBIX_SERVER_RELEASE_URL="${ANSIBLE_ZABBIX_SERVER_RELEASE_URL:-${ANSIBLE_ZABBIX_AGENT_RELEASE_URL}}"
ANSIBLE_ZABBIX_SERVER_OFFLINE_PACKAGES="${ANSIBLE_ZABBIX_SERVER_OFFLINE_PACKAGES:-zabbix-server-pgsql zabbix-frontend-php php8.3-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent systemd-sysv}"

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

if ! docker inspect --type image "${PACKAGE_IMAGE}" >/dev/null 2>&1; then
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

download_ubuntu_packages() {
  local repo_dir="$1"
  local packages="$2"
  local label="$3"

  mkdir -p "${repo_dir}"

  echo "Downloading ${label} offline packages into: ${repo_dir}"
  docker run --rm \
    --tmpfs /tmp:exec,mode=1777 \
    --tmpfs /var/lib/apt/lists:exec,mode=755 \
    --tmpfs /var/cache/apt:exec,mode=755 \
    -e "OFFLINE_PACKAGES=${packages}" \
    -v "${repo_dir}:/offline-debs" \
    "${ANSIBLE_PREREQUISITE_DOWNLOAD_IMAGE}" \
    bash -lc '
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      chmod 1777 /tmp
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
      apt-get -o Acquire::Retries=5 update
      mkdir -p /offline-debs/partial
      apt-get install -y --download-only --no-install-recommends \
        -o Acquire::Retries=5 \
        -o Dir::Cache::archives=/offline-debs \
        ${OFFLINE_PACKAGES}
      find /offline-debs -maxdepth 1 -type f -name "*.deb" -print | sort
    '
}

download_zabbix_packages() {
  local repo_dir="$1"
  local release_url="$2"
  local packages="$3"
  local label="$4"

  mkdir -p "${repo_dir}"

  echo "Downloading ${label} offline packages into: ${repo_dir}"
  docker run --rm \
    --tmpfs /tmp:exec,mode=1777 \
    --tmpfs /var/lib/apt/lists:exec,mode=755 \
    --tmpfs /var/cache/apt:exec,mode=755 \
    -e "ZABBIX_RELEASE_URL=${release_url}" \
    -e "ZABBIX_PACKAGES=${packages}" \
    -v "${repo_dir}:/zabbix-debs" \
    "${ANSIBLE_ZABBIX_AGENT_DOWNLOAD_IMAGE}" \
    bash -lc '
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      chmod 1777 /tmp
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
      apt-get -o Acquire::Retries=5 update
      apt-get install -y --no-install-recommends ca-certificates wget
      wget -O /tmp/zabbix-release.deb "${ZABBIX_RELEASE_URL}"
      dpkg -i /tmp/zabbix-release.deb
      rm -rf /var/lib/apt/lists/*
      apt-get -o Acquire::Retries=5 update
      mkdir -p /zabbix-debs/partial
      apt-get install -y --download-only --no-install-recommends \
        -o Acquire::Retries=5 \
        -o Dir::Cache::archives=/zabbix-debs \
        ${ZABBIX_PACKAGES}
      find /zabbix-debs -maxdepth 1 -type f -name "*.deb" -print | sort
    '
}

if [[ "${ANSIBLE_PREREQUISITE_DOWNLOAD_PACKAGES}" == "true" ]]; then
  download_ubuntu_packages \
    "$(project_path "${ANSIBLE_PREREQUISITE_REPO_SOURCE}")" \
    "${ANSIBLE_PREREQUISITE_OFFLINE_PACKAGES}" \
    "prerequisite"

  download_ubuntu_packages \
    "$(project_path "${ANSIBLE_PACKAGE_UPDATE_REPO_SOURCE}")" \
    "${ANSIBLE_PACKAGE_UPDATE_OFFLINE_PACKAGES}" \
    "package update"
fi

if [[ "${ANSIBLE_ZABBIX_AGENT_DOWNLOAD_PACKAGES}" == "true" ]]; then
  download_zabbix_packages \
    "$(project_path "${ANSIBLE_ZABBIX_AGENT_REPO_SOURCE}")" \
    "${ANSIBLE_ZABBIX_AGENT_RELEASE_URL}" \
    "${ANSIBLE_ZABBIX_AGENT_OFFLINE_PACKAGES}" \
    "Zabbix Agent 2"
fi

if [[ "${ANSIBLE_ZABBIX_SERVER_DOWNLOAD_PACKAGES}" == "true" ]]; then
  download_zabbix_packages \
    "$(project_path "${ANSIBLE_ZABBIX_SERVER_REPO_SOURCE}")" \
    "${ANSIBLE_ZABBIX_SERVER_RELEASE_URL}" \
    "${ANSIBLE_ZABBIX_SERVER_OFFLINE_PACKAGES}" \
    "Zabbix Server"
fi

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
  --exclude='./.env' \
  --exclude='./.env.example' \
  --exclude='./env.d/*.env' \
  --exclude='./env.d/*.env.example' \
  --exclude='./inventories/customer-a/secrets/id_*' \
  --exclude='./inventories/customer-a/secrets/*.yaml' \
  -C "${ROOT_DIR}" \
  -cf - \
  . | tar -C "${PROJECT_DIR}" -xf -

mkdir -p "${PROJECT_DIR}/inventories/customer-a/secrets"
touch "${PROJECT_DIR}/inventories/customer-a/secrets/.gitkeep"

if [[ "${ANSIBLE_OFFLINE_BUNDLE_INCLUDE_REAL_ENV}" == "true" ]]; then
  echo "Copying real .env and env.d/*.env files into offline bundle."
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    cp "${ROOT_DIR}/.env" "${PROJECT_DIR}/.env"
  else
    echo "ERROR: ANSIBLE_OFFLINE_BUNDLE_INCLUDE_REAL_ENV=true but ${ROOT_DIR}/.env does not exist." >&2
    exit 1
  fi

  mkdir -p "${PROJECT_DIR}/env.d"
  shopt -s nullglob
  real_env_count=0
  for env_file in "${ROOT_DIR}"/env.d/*.env; do
    cp "${env_file}" "${PROJECT_DIR}/env.d/$(basename "${env_file}")"
    real_env_count=$((real_env_count + 1))
  done
  shopt -u nullglob
  if [[ "${real_env_count}" -eq 0 ]]; then
    echo "ERROR: ANSIBLE_OFFLINE_BUNDLE_INCLUDE_REAL_ENV=true but no env.d/*.env files exist." >&2
    exit 1
  fi
else
  # Copy .env.example files as starting templates so the operator only needs
  # to fill in values rather than creating files from scratch.
  if [[ -f "${ROOT_DIR}/.env.example" ]]; then
    cp "${ROOT_DIR}/.env.example" "${PROJECT_DIR}/.env"
  fi
  for example_file in "${ROOT_DIR}"/env.d/*.env.example; do
    [[ -f "${example_file}" ]] || continue
    target="${PROJECT_DIR}/env.d/$(basename "${example_file}" .example)"
    cp "${example_file}" "${target}"
  done
fi

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

Edit \`project/.env\` for common SSH/runtime settings. Edit
\`project/env.d/*.env\` for inventory and task-specific settings, then run:

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
