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

ensure_inventory_env_loaded() {
  local has_hosts="false"
  local var_name

  for var_name in ANSIBLE_SWARM_MANAGER_HOSTS ANSIBLE_ALL_TARGET_HOSTS \
                  ANSIBLE_ZABBIX_SERVER_HOSTS ANSIBLE_ZABBIX_AGENT_HOSTS ANSIBLE_DNS_TIME_SERVER_HOSTS \
                  ANSIBLE_EXTERNAL_DISK_HOSTS ANSIBLE_TLDH_DATABASE_MASTER_HOST; do
    if [[ -n "${!var_name:-}" ]]; then
      has_hosts="true"
      break
    fi
  done

  if [[ "${has_hosts}" == "false" ]]; then
    echo "" >&2
    echo "ERROR: All inventory host variables are empty." >&2
    echo "env.d/10-inventory.env was not loaded or contains no host definitions." >&2
    echo "Ansible will not find any hosts to target." >&2
    echo "" >&2
    echo "Troubleshooting:" >&2
    echo "  1. Verify env.d/10-inventory.env exists and contains real host values" >&2
    echo "  2. If this is an offline bundle, rebuild/copy it with real env files included" >&2
    echo "  3. Run: source scripts/lib/env.sh && load_ansible_env \"\$(pwd)\" && echo \"\${ANSIBLE_ALL_TARGET_HOSTS}\"" >&2
    echo "  4. On the server, check file permissions: ls -la env.d/10-inventory.env" >&2
    echo "" >&2
    exit 1
  fi
}

ensure_inventory_env_loaded

DEFAULT_ANSIBLE_IMAGE="ansible-base-runtime:local"
LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE:-${DEFAULT_ANSIBLE_IMAGE}}"
RUNTIME_IMAGE="${RUNTIME_IMAGE:-}"
ANSIBLE_CONTROL_OFFLINE="${ANSIBLE_CONTROL_OFFLINE:-false}"
ANSIBLE_SSH_USER="${ANSIBLE_SSH_USER:-bcy_admin}"
ANSIBLE_BECOME="${ANSIBLE_BECOME:-true}"
export ANSIBLE_SSH_USER
export ANSIBLE_BECOME

ANSIBLE_SSH_USER_LOWER="$(printf '%s' "${ANSIBLE_SSH_USER}" | tr '[:upper:]' '[:lower:]')"
ANSIBLE_BECOME_LOWER="$(printf '%s' "${ANSIBLE_BECOME}" | tr '[:upper:]' '[:lower:]')"

if [[ "${ANSIBLE_SSH_USER_LOWER}" == "root" ]]; then
  echo "ERROR: Do not SSH as root. Set ANSIBLE_SSH_USER to a sudo-capable user, for example bcy_admin." >&2
  echo "Privileged tasks will use Ansible become/sudo after connecting as that user." >&2
  exit 1
fi

case "${ANSIBLE_BECOME_LOWER}" in
  1|true|yes|on)
    ;;
  *)
    echo "ERROR: ANSIBLE_BECOME must be true. Connect with a sudo-capable SSH user and run privileged tasks through sudo." >&2
    exit 1
    ;;
esac

if [[ "${RUNTIME_IMAGE}" == *.tar || "${RUNTIME_IMAGE}" == *.tar.gz ]]; then
  echo "Ignoring RUNTIME_IMAGE tar path while running Ansible: ${RUNTIME_IMAGE}" >&2
  echo "Load runtime image tars with ./scripts/prepare-offline-control.sh, then use LOCAL_RUNTIME_IMAGE." >&2
  RUNTIME_IMAGE=""
fi

resolve_project_path() {
  local path="$1"
  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s/%s\n' "${ROOT_DIR}" "${path#./}"
  fi
}

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
  if docker inspect --type image "${ANSIBLE_IMAGE}" >/dev/null 2>&1; then
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

ensure_prerequisite_playbook_is_current() {
  local has_prerequisite_tag="false"
  local previous_was_tags="false"
  local arg
  local tag

  for arg in "$@"; do
    if [[ "${previous_was_tags}" == "true" ]]; then
      IFS=',' read -ra _tags <<< "${arg}"
      for tag in "${_tags[@]}"; do
        [[ "${tag//[[:space:]]/}" == "prerequisite" ]] && has_prerequisite_tag="true"
      done
      previous_was_tags="false"
      continue
    fi

    case "${arg}" in
      --tags|-t)
        previous_was_tags="true"
        ;;
      --tags=*)
        IFS=',' read -ra _tags <<< "${arg#--tags=}"
        for tag in "${_tags[@]}"; do
          [[ "${tag//[[:space:]]/}" == "prerequisite" ]] && has_prerequisite_tag="true"
        done
        ;;
      -t=*)
        IFS=',' read -ra _tags <<< "${arg#-t=}"
        for tag in "${_tags[@]}"; do
          [[ "${tag//[[:space:]]/}" == "prerequisite" ]] && has_prerequisite_tag="true"
        done
        ;;
    esac
  done

  if [[ "${has_prerequisite_tag}" == "true" ]] && ! grep -q "ANSIBLE_PREREQUISITE_TARGET_GROUP" "${ROOT_DIR}/${PLAYBOOK_PATH}"; then
    echo "" >&2
    echo "ERROR: ${PLAYBOOK_PATH} is stale for --tags prerequisite." >&2
    echo "The current prerequisite play must target ANSIBLE_PREREQUISITE_TARGET_GROUP/all_targets." >&2
    echo "This copy still targets linux, so hosts outside swarm/linux will be skipped." >&2
    echo "" >&2
    echo "Fix:" >&2
    echo "  1. Copy/rebuild the offline bundle with the latest playbooks/deploy.yaml" >&2
    echo "  2. Verify: grep -n ANSIBLE_PREREQUISITE_TARGET_GROUP playbooks/deploy.yaml" >&2
    echo "" >&2
    exit 1
  fi
}

inventory_limit_host() {
  local value="$1"
  python3 - "${ROOT_DIR}" "${value}" <<'PY'
import importlib.util
import sys

root_dir = sys.argv[1]
limit_value = sys.argv[2]
inventory_path = f"{root_dir}/inventories/customer-a/inventory.py"

spec = importlib.util.spec_from_file_location("customer_inventory", inventory_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

hostvars_by_alias = module.build_inventory().get("_meta", {}).get("hostvars", {})
if limit_value in hostvars_by_alias:
    ansible_host = hostvars_by_alias[limit_value].get("ansible_host")
    if ansible_host in hostvars_by_alias:
        print(ansible_host)
    else:
        print(limit_value)
    sys.exit(0)

for alias, hostvars in hostvars_by_alias.items():
    if hostvars.get("ansible_host") == limit_value:
        print(alias)
        break
PY
}

translate_limit_value() {
  local value="$1"
  local resolved

  resolved="$(inventory_limit_host "${value}")"
  if [[ -n "${resolved}" ]]; then
    if [[ "${resolved}" != "${value}" ]]; then
      echo "Resolved --limit ${value} to inventory host ${resolved}" >&2
    fi
    printf '%s\n' "${resolved}"
    return 0
  fi

  if [[ "${value}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "WARNING: --limit ${value} did not match any ansible_host in inventory; passing it through unchanged." >&2
  fi
  printf '%s\n' "${value}"
}

PLAYBOOK_ARGS=()
_translate_next_limit="false"
for arg in "${@:2}"; do
  if [[ "${_translate_next_limit}" == "true" ]]; then
    PLAYBOOK_ARGS+=("$(translate_limit_value "${arg}")")
    _translate_next_limit="false"
    continue
  fi

  case "${arg}" in
    --limit|-l)
      PLAYBOOK_ARGS+=("${arg}")
      _translate_next_limit="true"
      ;;
    --limit=*)
      PLAYBOOK_ARGS+=("--limit=$(translate_limit_value "${arg#--limit=}")")
      ;;
    -l=*)
      PLAYBOOK_ARGS+=("-l=$(translate_limit_value "${arg#-l=}")")
      ;;
    *)
      PLAYBOOK_ARGS+=("${arg}")
      ;;
  esac
done

ensure_prerequisite_playbook_is_current "${PLAYBOOK_ARGS[@]}"

validate_limited_hosts_for_selected_tags() {
  python3 - "${ROOT_DIR}" "${PLAYBOOK_ARGS[@]}" <<'PY'
import importlib.util
import os
import sys

root_dir = sys.argv[1]
args = sys.argv[2:]
inventory_path = f"{root_dir}/inventories/customer-a/inventory.py"

limits = []
tags = []
next_is_limit = False
next_is_tags = False
for arg in args:
    if next_is_limit:
        limits.append(arg)
        next_is_limit = False
        continue
    if next_is_tags:
        tags.extend([item.strip() for item in arg.split(",") if item.strip()])
        next_is_tags = False
        continue

    if arg in ("--limit", "-l"):
        next_is_limit = True
    elif arg.startswith("--limit="):
        limits.append(arg.split("=", 1)[1])
    elif arg.startswith("-l="):
        limits.append(arg.split("=", 1)[1])
    elif arg in ("--tags", "-t"):
        next_is_tags = True
    elif arg.startswith("--tags="):
        tags.extend([item.strip() for item in arg.split("=", 1)[1].split(",") if item.strip()])
    elif arg.startswith("-t="):
        tags.extend([item.strip() for item in arg.split("=", 1)[1].split(",") if item.strip()])

if "prerequisite" not in tags or not limits:
    sys.exit(0)

spec = importlib.util.spec_from_file_location("customer_inventory", inventory_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
inventory = module.build_inventory()
hostvars = inventory.get("_meta", {}).get("hostvars", {})
target_group = os.environ.get("ANSIBLE_PREREQUISITE_TARGET_GROUP") or "all_targets"

def group_hosts(group, seen=None):
    seen = seen or set()
    if group in seen:
        return set()
    seen.add(group)

    group_data = inventory.get(group, {})
    hosts = set(group_data.get("hosts", []))
    for child in group_data.get("children", []):
        hosts.update(group_hosts(child, seen))
    return hosts

target_hosts = group_hosts(target_group)
errors = []
for raw_limit in limits:
    for item in [part.strip() for part in raw_limit.replace(":", ",").split(",") if part.strip()]:
        if any(char in item for char in "*?[]!&"):
            continue

        matching_aliases = []
        if item in hostvars:
            matching_aliases.append(item)
        matching_aliases.extend(
            alias for alias, vars_ in hostvars.items()
            if vars_.get("ansible_host") == item and alias not in matching_aliases
        )

        if not matching_aliases:
            errors.append(
                f"--limit {item} is not present in inventory. Check env.d/10-inventory.env."
            )
            continue

        if not any(alias in target_hosts for alias in matching_aliases):
            errors.append(
                f"--limit {item} resolved to {', '.join(matching_aliases)}, but none are in "
                f"ANSIBLE_PREREQUISITE_TARGET_GROUP={target_group}."
            )

if errors:
    print("")
    print("ERROR: prerequisite limit does not match selected inventory hosts.", file=sys.stderr)
    print(f"Target group: {target_group}", file=sys.stderr)
    print(f"Target hosts: {', '.join(sorted(target_hosts)) or '(empty)'}", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    print("", file=sys.stderr)
    sys.exit(1)

print(
    f"Validated prerequisite --limit against {target_group}: "
    f"{', '.join(limits)}",
    file=sys.stderr,
)
PY
}

validate_limited_hosts_for_selected_tags

has_playbook_tag() {
  local wanted="$1"
  shift || true
  local previous_was_tags="false"
  local arg
  local tag

  for arg in "$@"; do
    if [[ "${previous_was_tags}" == "true" ]]; then
      IFS=',' read -ra _tags <<< "${arg}"
      for tag in "${_tags[@]}"; do
        [[ "${tag//[[:space:]]/}" == "${wanted}" ]] && return 0
      done
      previous_was_tags="false"
      continue
    fi

    case "${arg}" in
      --tags|-t)
        previous_was_tags="true"
        ;;
      --tags=*)
        IFS=',' read -ra _tags <<< "${arg#--tags=}"
        for tag in "${_tags[@]}"; do
          [[ "${tag//[[:space:]]/}" == "${wanted}" ]] && return 0
        done
        ;;
      -t=*)
        IFS=',' read -ra _tags <<< "${arg#-t=}"
        for tag in "${_tags[@]}"; do
          [[ "${tag//[[:space:]]/}" == "${wanted}" ]] && return 0
        done
        ;;
    esac
  done

  return 1
}

scope_prerequisite_limits_to_target_group() {
  python3 - "$@" <<'PY'
import os
import sys

args = sys.argv[1:]
tags = []
next_is_tags = False
for arg in args:
    if next_is_tags:
        tags.extend([item.strip() for item in arg.split(",") if item.strip()])
        next_is_tags = False
        continue
    if arg in ("--tags", "-t"):
        next_is_tags = True
    elif arg.startswith("--tags="):
        tags.extend([item.strip() for item in arg.split("=", 1)[1].split(",") if item.strip()])
    elif arg.startswith("-t="):
        tags.extend([item.strip() for item in arg.split("=", 1)[1].split(",") if item.strip()])

target_group = os.environ.get("ANSIBLE_PREREQUISITE_TARGET_GROUP") or "all_targets"
if "prerequisite" not in tags:
    print("\0".join(args) + "\0", end="")
    sys.exit(0)

scoped = []
next_is_limit = False
for arg in args:
    if next_is_limit:
        if not any(char in arg for char in ":,!&*?[]"):
            arg = f"{target_group}:&{arg}"
        scoped.append(arg)
        next_is_limit = False
        continue

    if arg in ("--limit", "-l"):
        scoped.append(arg)
        next_is_limit = True
    elif arg.startswith("--limit="):
        value = arg.split("=", 1)[1]
        if not any(char in value for char in ":,!&*?[]"):
            value = f"{target_group}:&{value}"
        scoped.append(f"--limit={value}")
    elif arg.startswith("-l="):
        value = arg.split("=", 1)[1]
        if not any(char in value for char in ":,!&*?[]"):
            value = f"{target_group}:&{value}"
        scoped.append(f"-l={value}")
    else:
        scoped.append(arg)

print("\0".join(scoped) + "\0", end="")
PY
}

if has_playbook_tag prerequisite "${PLAYBOOK_ARGS[@]}"; then
  SCOPED_PLAYBOOK_ARGS=()
  while IFS= read -r -d '' arg; do
    SCOPED_PLAYBOOK_ARGS+=("${arg}")
  done < <(scope_prerequisite_limits_to_target_group "${PLAYBOOK_ARGS[@]}")
  PLAYBOOK_ARGS=("${SCOPED_PLAYBOOK_ARGS[@]}")
fi

IS_LIST_HOSTS_RUN=false
for arg in "${PLAYBOOK_ARGS[@]}"; do
  if [[ "${arg}" == "--list-hosts" ]]; then
    IS_LIST_HOSTS_RUN=true
    break
  fi
done

HAS_LIMIT_RUN=false
for arg in "${PLAYBOOK_ARGS[@]}"; do
  case "${arg}" in
    --limit|-l|--limit=*|-l=*)
      HAS_LIMIT_RUN=true
      break
      ;;
  esac
done

PRIVATE_KEY_PATH="$(resolve_project_path "${ANSIBLE_SSH_PRIVATE_KEY_FILE:-./inventories/customer-a/secrets/id_rsa}")"
IS_SSH_COPY_ID_PLAYBOOK=false
if [[ "${PLAYBOOK_PATH}" == "playbooks/ssh-copy-id."* ]]; then
  IS_SSH_COPY_ID_PLAYBOOK=true
fi

if [[ "${IS_LIST_HOSTS_RUN}" == "true" ]]; then
  ANSIBLE_SSH_PASSWORD_AUTH="false"
elif [[ "${IS_SSH_COPY_ID_PLAYBOOK}" == "true" && -n "${ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE:-}" ]]; then
  ANSIBLE_SSH_PASSWORD_AUTH="${ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE}"
elif [[ "${IS_SSH_COPY_ID_PLAYBOOK}" == "true" ]]; then
  ANSIBLE_SSH_PASSWORD_AUTH="true"
elif [[ -f "${PRIVATE_KEY_PATH}" ]]; then
  ANSIBLE_SSH_PASSWORD_AUTH="false"
else
  echo "ERROR: SSH private key is required for ${PLAYBOOK_PATH}: ${PRIVATE_KEY_PATH}" >&2
  echo "Create/copy the key, run ./scripts/run-ansible.sh ssh-copy-id only for initial bootstrap if needed, then rerun with key auth." >&2
  exit 1
fi
export ANSIBLE_SSH_PASSWORD_AUTH

if [[ "${IS_LIST_HOSTS_RUN}" != "true" && "${IS_SSH_COPY_ID_PLAYBOOK}" != "true" && "${ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE:-}" == "true" ]]; then
  echo "ERROR: Password SSH auth is not allowed for ${PLAYBOOK_PATH}." >&2
  echo "Use ANSIBLE_SSH_PRIVATE_KEY_FILE with a non-root sudo user. Password auth is reserved for ssh-copy-id bootstrap only." >&2
  exit 1
fi

if [[ "${ANSIBLE_SSH_PASSWORD_AUTH}" == "true" ]]; then
  if [[ "${IS_SSH_COPY_ID_PLAYBOOK}" == "true" ]]; then
    echo "WARNING: using SSH password auth only to bootstrap/copy the public key." >&2
    echo "After this succeeds, run deploy normally; the wrapper will use the private key when it exists: ${PRIVATE_KEY_PATH}" >&2
  fi
  ANSIBLE_SSH_COMMON_ARGS="${ANSIBLE_SSH_COMMON_ARGS:--o PubkeyAuthentication=no -o PreferredAuthentications=password}"
  export ANSIBLE_SSH_COMMON_ARGS
  if [[ -z "${ANSIBLE_PASSWORD:-}" ]]; then
    echo "ERROR: password auth is required for this run, but ANSIBLE_PASSWORD is empty." >&2
    echo "Set ANSIBLE_PASSWORD in .env for bootstrap, or create ${PRIVATE_KEY_PATH} and rerun to use key auth." >&2
    exit 1
  fi
fi

INVENTORY_SECRET_VARS_RELATIVE="${ANSIBLE_INVENTORY_SECRET_VARS:-inventories/customer-a/secrets/auth.yaml}"
INVENTORY_SECRET_VARS="${ROOT_DIR}/${INVENTORY_SECRET_VARS_RELATIVE}"
EXTRA_ARGS=()
DOCKER_ENV_ARGS=(
  "-e" "ANSIBLE_SSH_PASSWORD_AUTH=${ANSIBLE_SSH_PASSWORD_AUTH}"
)

while IFS='=' read -r env_name _; do
  case "${env_name}" in
    ANSIBLE_PASSWORD|ANSIBLE_SSH_COMMON_ARGS|ANSIBLE_SSH_PASSWORD_AUTH_OVERRIDE)
      ;;
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

if [[ "${ANSIBLE_SSH_PASSWORD_AUTH}" == "true" && -n "${ANSIBLE_PASSWORD:-}" ]]; then
  EXTRA_ARGS+=("-e" "ansible_password=${ANSIBLE_PASSWORD}")
fi

if [[ -n "${ANSIBLE_BECOME_PASSWORD:-}" ]]; then
  EXTRA_ARGS+=("-e" "ansible_become_password=${ANSIBLE_BECOME_PASSWORD}")
fi

if [[ "${ANSIBLE_SSH_PASSWORD_AUTH}" != "true" && "${IS_LIST_HOSTS_RUN}" != "true" ]]; then
  EXTRA_ARGS+=("-e" "ansible_ssh_private_key_file=${ANSIBLE_SSH_PRIVATE_KEY_FILE:-./inventories/customer-a/secrets/id_rsa}")
fi

# Force ansible_user via extra-vars (highest priority) to guarantee the
# correct SSH user regardless of inventory/config state inside the container.
if [[ -n "${ANSIBLE_SSH_USER:-}" ]]; then
  EXTRA_ARGS+=("-e" "ansible_user=${ANSIBLE_SSH_USER}")
fi

if ! docker inspect --type image "${ANSIBLE_IMAGE}" >/dev/null 2>&1; then
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

if [[ "${HAS_LIMIT_RUN}" == "true" ]]; then
  printf 'Effective ansible args:' >&2
  for arg in "${PLAYBOOK_ARGS[@]}"; do
    printf ' %q' "${arg}" >&2
  done
  printf '\n' >&2

  echo "Container inventory check for all_targets:" >&2
  ANSIBLE_IMAGE="${ANSIBLE_IMAGE}" LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE}" \
    docker compose -f "${ROOT_DIR}/docker-compose.yaml" run --rm "${DOCKER_ENV_ARGS[@]}" ansible \
      ansible-inventory -i inventories/customer-a/inventory.py --graph all_targets
fi

if [[ "${HAS_LIMIT_RUN}" == "true" && "${IS_LIST_HOSTS_RUN}" != "true" ]]; then
  echo "Container playbook host match check:" >&2
  _list_hosts_output="$(
    ANSIBLE_IMAGE="${ANSIBLE_IMAGE}" LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE}" \
      docker compose -f "${ROOT_DIR}/docker-compose.yaml" run --rm "${DOCKER_ENV_ARGS[@]}" ansible \
        ansible-playbook -i inventories/customer-a/inventory.py "${PLAYBOOK_PATH}" "${EXTRA_ARGS[@]}" "${PLAYBOOK_ARGS[@]}" --list-hosts
  )"
  printf '%s\n' "${_list_hosts_output}"
fi

ANSIBLE_IMAGE="${ANSIBLE_IMAGE}" LOCAL_RUNTIME_IMAGE="${LOCAL_RUNTIME_IMAGE}" \
  docker compose -f "${ROOT_DIR}/docker-compose.yaml" run --rm "${DOCKER_ENV_ARGS[@]}" ansible ansible-playbook -i inventories/customer-a/inventory.py "${PLAYBOOK_PATH}" "${EXTRA_ARGS[@]}" "${PLAYBOOK_ARGS[@]}"
