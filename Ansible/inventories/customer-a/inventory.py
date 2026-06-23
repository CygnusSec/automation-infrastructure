#!/usr/bin/env python3
import json
import os
import re
import sys


def csv_env(name, default=""):
    value = os.environ.get(name, default)
    items = [item.strip() for item in re.split(r"[,\s]+", value) if item.strip()]
    return list(dict.fromkeys(items))


def env_bool(name, default="false"):
    return os.environ.get(name, default).strip().lower() in ("1", "true", "yes", "on")


def host_alias(prefix, ip):
    return f"{prefix}-{ip.replace('.', '-')}"


def warn(message):
    print(f"inventory warning: {message}", file=sys.stderr)


def add_host(inventory, group, alias, ip, labels=None, advertise=True):
    inventory.setdefault(group, {"hosts": []})
    if alias not in inventory[group]["hosts"]:
        inventory[group]["hosts"].append(alias)

    hostvars = inventory["_meta"]["hostvars"].setdefault(alias, {})
    hostvars["ansible_host"] = ip
    if advertise:
        hostvars["docker_swarm_advertise_addr"] = ip
    if labels:
        hostvars["docker_swarm_node_labels"] = labels


def add_children(inventory, group, children):
    inventory.setdefault(group, {})
    inventory[group].setdefault("children", [])
    for child in children:
        if child not in inventory[group]["children"]:
            inventory[group]["children"].append(child)


def set_group_vars(inventory, group, vars_):
    inventory.setdefault(group, {})
    inventory[group].setdefault("vars", {}).update(vars_)


def connection_vars(become):
    password_auth = env_bool("ANSIBLE_SSH_PASSWORD_AUTH")
    return {
        "ansible_user": os.environ.get("ANSIBLE_SSH_USER", "bcy_admin"),
        "ansible_ssh_private_key_file": ""
        if password_auth
        else os.environ.get(
            "ANSIBLE_SSH_PRIVATE_KEY_FILE",
            "./inventories/customer-a/secrets/id_rsa",
        ),
        "ansible_become": become,
        "ansible_become_method": os.environ.get("ANSIBLE_BECOME_METHOD", "sudo"),
    }


def build_inventory():
    inventory = {
        "_meta": {"hostvars": {}},
        "all": {"children": ["all_targets", "ssh_copy_id_targets", "linux", "iptables_targets", "package_update_targets", "zabbix_server_targets", "zabbix_agent_targets", "dns_time_servers", "external_disk_targets", "tldh_database_targets"]},
    }

    manager_hosts = csv_env("ANSIBLE_SWARM_MANAGER_HOSTS", os.environ.get("ANSIBLE_MANAGER_1_HOST", ""))
    all_target_hosts = csv_env("ANSIBLE_ALL_TARGET_HOSTS")
    backend_hosts = csv_env("ANSIBLE_SWARM_BACKEND_WORKER_HOSTS")
    file_server_hosts = csv_env("ANSIBLE_SWARM_FILE_SERVER_WORKER_HOSTS")
    cache_ext_hosts = csv_env("ANSIBLE_SWARM_CACHE_SERVER_EXT_HOSTS")
    cache_ext_tags = csv_env("ANSIBLE_SWARM_CACHE_SERVER_EXT_TAGS")
    cache_int_hosts = csv_env("ANSIBLE_SWARM_CACHE_SERVER_INT_HOSTS")
    cache_int_tags = csv_env("ANSIBLE_SWARM_CACHE_SERVER_INT_TAGS")
    logger_hosts = set(csv_env("ANSIBLE_SWARM_LOGGER_HOSTS"))
    ssh_extra_hosts = csv_env("ANSIBLE_SSH_COPY_ID_EXTRA_HOSTS")
    iptables_hosts = csv_env("ANSIBLE_IPTABLES_HOSTS")
    package_update_hosts = csv_env("ANSIBLE_PACKAGE_UPDATE_HOSTS")
    zabbix_server_hosts = csv_env("ANSIBLE_ZABBIX_SERVER_HOSTS")
    zabbix_hosts = csv_env("ANSIBLE_ZABBIX_AGENT_HOSTS")
    dns_time_hosts = csv_env("ANSIBLE_DNS_TIME_SERVER_HOSTS")
    external_disk_hosts = csv_env("ANSIBLE_EXTERNAL_DISK_HOSTS")
    tldh_database_master_hosts = csv_env("ANSIBLE_TLDH_DATABASE_MASTER_HOST")
    tldh_database_slave_hosts = csv_env("ANSIBLE_TLDH_DATABASE_SLAVE_HOSTS")

    # Early warning: detect missing inventory environment variables.
    if not manager_hosts and not all_target_hosts and not backend_hosts:
        warn(
            "all inventory host variables are empty. "
            "Ensure ANSIBLE_SWARM_MANAGER_HOSTS or ANSIBLE_ALL_TARGET_HOSTS is set. "
            "Check that env.d/10-inventory.env is loaded correctly."
        )

    if cache_ext_tags and len(cache_ext_tags) != len(cache_ext_hosts):
        warn("ANSIBLE_SWARM_CACHE_SERVER_EXT_TAGS count does not match ANSIBLE_SWARM_CACHE_SERVER_EXT_HOSTS")

    if cache_int_tags and len(cache_int_tags) != len(cache_int_hosts):
        warn("ANSIBLE_SWARM_CACHE_SERVER_INT_TAGS count does not match ANSIBLE_SWARM_CACHE_SERVER_INT_HOSTS")

    def node_labels(ip, default_tag=None):
        if ip in logger_hosts:
            return {"node_tag": "logger"}
        if default_tag:
            return {"node_tag": default_tag}
        return None

    for index, ip in enumerate(manager_hosts, start=1):
        add_host(inventory, "swarm_managers", f"swarm-manager-{index:02d}", ip, node_labels(ip))

    for ip in backend_hosts:
        add_host(
            inventory,
            "swarm_backend_workers",
            host_alias("backend", ip),
            ip,
            node_labels(ip, "backend"),
        )

    for ip in file_server_hosts:
        add_host(
            inventory,
            "swarm_file_server_workers",
            host_alias("file-server", ip),
            ip,
            node_labels(ip, "file-server"),
        )

    for index, ip in enumerate(cache_ext_hosts, start=1):
        tag = cache_ext_tags[index - 1] if index <= len(cache_ext_tags) else f"cache-server-ext-{index:02d}"
        add_host(inventory, "swarm_cache_ext_workers", tag, ip, node_labels(ip, tag))

    for index, ip in enumerate(cache_int_hosts, start=1):
        tag = cache_int_tags[index - 1] if index <= len(cache_int_tags) else f"cache-server-int-{index:02d}"
        add_host(inventory, "swarm_cache_int_workers", tag, ip, node_labels(ip, tag))

    for ip in ssh_extra_hosts:
        add_host(inventory, "ssh_copy_id_extra_targets", host_alias("ssh-target", ip), ip, advertise=False)

    swarm_worker_groups = [
        "swarm_backend_workers",
        "swarm_file_server_workers",
        "swarm_cache_ext_workers",
        "swarm_cache_int_workers",
    ]
    add_children(inventory, "swarm_workers", swarm_worker_groups)
    add_children(inventory, "linux", ["swarm_managers", "swarm_workers"])
    add_children(
        inventory,
        "ssh_copy_id_targets",
        [
            "swarm_managers",
            "swarm_workers",
            "external_disk_targets",
            "ssh_copy_id_extra_targets",
        ],
    )

    ip_to_alias = {
        hostvars["ansible_host"]: alias
        for alias, hostvars in inventory["_meta"]["hostvars"].items()
    }

    for ip in dns_time_hosts:
        alias = ip_to_alias.get(ip, host_alias("dns-time", ip))
        add_host(inventory, "dns_time_servers", alias, ip, advertise=False)

    ip_to_alias = {
        hostvars["ansible_host"]: alias
        for alias, hostvars in inventory["_meta"]["hostvars"].items()
    }

    for ip in external_disk_hosts:
        alias = ip_to_alias.get(ip, host_alias("external-disk", ip))
        add_host(inventory, "external_disk_targets", alias, ip, advertise=False)

    ip_to_alias = {
        hostvars["ansible_host"]: alias
        for alias, hostvars in inventory["_meta"]["hostvars"].items()
    }

    for index, ip in enumerate(tldh_database_master_hosts, start=1):
        alias = ip_to_alias.get(ip, f"tldh-db-master-{index:02d}")
        add_host(inventory, "tldh_database_masters", alias, ip, advertise=False)

    ip_to_alias = {
        hostvars["ansible_host"]: alias
        for alias, hostvars in inventory["_meta"]["hostvars"].items()
    }

    for index, ip in enumerate(tldh_database_slave_hosts, start=1):
        alias = ip_to_alias.get(ip, f"tldh-db-slave-{index:02d}")
        add_host(inventory, "tldh_database_slaves", alias, ip, advertise=False)

    add_children(inventory, "tldh_database_targets", ["tldh_database_masters", "tldh_database_slaves"])

    ip_to_alias = {
        hostvars["ansible_host"]: alias
        for alias, hostvars in inventory["_meta"]["hostvars"].items()
    }

    for ip in all_target_hosts:
        alias = ip_to_alias.get(ip, host_alias("target", ip))
        add_host(inventory, "all_targets", alias, ip, advertise=False)

    for ip in iptables_hosts:
        alias = ip_to_alias.get(ip, host_alias("iptables", ip))
        add_host(inventory, "iptables_targets", alias, ip, advertise=False)

    for ip in package_update_hosts:
        alias = ip_to_alias.get(ip, host_alias("package-update", ip))
        add_host(inventory, "package_update_targets", alias, ip, advertise=False)

    for ip in zabbix_server_hosts:
        alias = ip_to_alias.get(ip, host_alias("zabbix-server", ip))
        add_host(inventory, "zabbix_server_targets", alias, ip, advertise=False)

    for ip in zabbix_hosts:
        alias = ip_to_alias.get(ip, host_alias("zabbix-agent", ip))
        add_host(inventory, "zabbix_agent_targets", alias, ip, advertise=False)

    set_group_vars(inventory, "linux", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "all_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "iptables_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "package_update_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "zabbix_server_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "zabbix_agent_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "dns_time_servers", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "external_disk_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "tldh_database_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(
        inventory,
        "ssh_copy_id_targets",
        {
            key: value
            for key, value in connection_vars(become=env_bool("ANSIBLE_BECOME", "true")).items()
            if key != "ansible_become"
        },
    )

    return inventory


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--host":
        print(json.dumps({}))
    else:
        print(json.dumps(build_inventory(), indent=2, sort_keys=True))
