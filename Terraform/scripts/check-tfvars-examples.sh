#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

cp "${ROOT_DIR}/envs/vcenter/variables.tf" "${TEMP_DIR}/variables.tf"

example_count=0
while IFS= read -r -d '' source_file; do
  relative_path="${source_file#"${ROOT_DIR}/"}"
  target_file="${TEMP_DIR}/${relative_path%.example}"
  mkdir -p "$(dirname "${target_file}")"
  cp "${source_file}" "${target_file}"
  if ! terraform fmt -check "${target_file}" >/dev/null; then
    echo "Invalid or unformatted Terraform variable example: ${relative_path}" >&2
    exit 1
  fi
  if ! printf '%s\n' 'length(var.vms)' | terraform -chdir="${TEMP_DIR}" console \
    -var-file="${target_file}" \
    -var=vsphere_server=example.invalid \
    -var=vsphere_user=example \
    -var=vsphere_password=example \
    -var=datacenter=example \
    -var=datastore=example \
    -var=network=example \
    -var=template_name=example >/dev/null; then
    echo "Terraform type check failed for variable example: ${relative_path}" >&2
    exit 1
  fi
  example_count=$((example_count + 1))
done < <(find "${ROOT_DIR}/envs" -type f \( -name '*.tfvars.example' -o -name '*.tfvars.json.example' \) -print0)

if [[ "${example_count}" -eq 0 ]]; then
  echo "No Terraform variable examples found" >&2
  exit 1
fi

echo "Validated ${example_count} Terraform variable example files"
