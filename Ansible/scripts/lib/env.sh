#!/usr/bin/env bash

load_ansible_env() {
  local root_dir="$1"
  shift || true
  local env_file="${root_dir}/.env"
  local env_dir="${root_dir}/env.d"
  local env_fragment
  local selected_files=()
  local load_all="true"
  local tags=""
  local context="${ANSIBLE_ENV_CONTEXT:-run}"
  local arg
  local env_name
  local previous_was_tags="false"

  for arg in "$@"; do
    if [[ "${previous_was_tags}" == "true" ]]; then
      tags="${tags},${arg}"
      previous_was_tags="false"
      continue
    fi

    case "${arg}" in
      --tags|-t)
        previous_was_tags="true"
        ;;
      --tags=*)
        tags="${tags},${arg#--tags=}"
        ;;
      -t=*)
        tags="${tags},${arg#-t=}"
        ;;
    esac
  done

  env_file_for_tag() {
    local tag="$1"
    case "${tag}" in
      base|prerequisite|docker|installation_cleanup|user_password|kesl_stop|kesl_start|kesl_enable|iptable|iptables|iptables_primary|iptables_zabbix|iptables_ipsets|iptables_save|iptable_accept|iptables_accept|iptable_block|iptables_block|mariadb_remove|openresty_remove|apache2_remove)
        printf '%s\n' "20-base.env"
        ;;
      hostname|network)
        printf '%s\n' "25-host-network.env"
        ;;
      zabbix|zabbix_server|zabbix_agent|zabbix_agent_uninstall)
        printf '%s\n' "30-zabbix-agent.env"
        ;;
      dns_time_services|dns_server|time_server|ntp_client)
        printf '%s\n' "40-dns-time.env"
        ;;
      external_disk)
        printf '%s\n' "50-external-disk.env"
        ;;
      docker_swarm|docker_swarm_iptables|docker_swarm_iptables_ipsets|docker_swarm_iptables_nodes|docker_swarm_iptables_allow_connect_in|docker_swarm_iptables_allow_connect_out|docker_swarm_labels|docker_swarm_reset|docker_swarm_leave)
        printf '%s\n' "60-docker-swarm.env"
        ;;
      tldh_database)
        printf '%s\n' "70-tldh-database.env"
        ;;
      package_update|cve_update|python3_pip_remove|cve_python3_pip_remove)
        printf '%s\n' "80-package-update.env"
        ;;
      all|always)
        printf '%s\n' "__all__"
        ;;
    esac
  }

  append_unique_env_file() {
    local file="$1"
    local existing
    [[ -n "${file}" ]] || return 0
    if (( ${#selected_files[@]} > 0 )); then
      for existing in "${selected_files[@]}"; do
        [[ "${existing}" == "${file}" ]] && return 0
      done
    fi
    selected_files+=("${file}")
  }

  if [[ -n "${tags}" ]]; then
    load_all="false"
    IFS=',' read -ra tag_items <<< "${tags}"
    for tag in "${tag_items[@]}"; do
      tag="${tag//[[:space:]]/}"
      env_name="$(env_file_for_tag "${tag}")"
      if [[ "${env_name}" == "__all__" ]]; then
        load_all="true"
        break
      fi
      append_unique_env_file "${env_name}"
    done
  fi

  set -a
  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  fi

  if [[ -d "${env_dir}" ]]; then
    for env_fragment in "${env_dir}"/00-*.env "${env_dir}"/10-inventory.env; do
      [[ -f "${env_fragment}" ]] || continue
      # shellcheck disable=SC1090
      source "${env_fragment}"
    done

    if [[ "${load_all}" == "true" ]]; then
      for env_fragment in "${env_dir}"/*.env; do
        [[ -f "${env_fragment}" ]] || continue
        if [[ "${context}" != "offline_bundle" && "$(basename "${env_fragment}")" == 90-*.env ]]; then
          continue
        fi
        # shellcheck disable=SC1090
        source "${env_fragment}"
      done
    else
      if (( ${#selected_files[@]} > 0 )); then
        for env_name in "${selected_files[@]}"; do
          env_fragment="${env_dir}/${env_name}"
          [[ -f "${env_fragment}" ]] || continue
          # shellcheck disable=SC1090
          source "${env_fragment}"
        done
      fi
    fi
  fi
  set +a
}
