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
        "all": {"children": ["all_targets", "ssh_copy_id_targets", "linux", "zabbix_agent_targets"]},
    }

    manager_hosts = csv_env("ANSIBLE_SWARM_MANAGER_HOSTS", os.environ.get("ANSIBLE_MANAGER_1_HOST", "172.16.5.3"))
    all_target_hosts = csv_env("ANSIBLE_ALL_TARGET_HOSTS")
    backend_hosts = csv_env("ANSIBLE_SWARM_BACKEND_WORKER_HOSTS")
    file_server_hosts = csv_env("ANSIBLE_SWARM_FILE_SERVER_WORKER_HOSTS")
    cache_ext_hosts = csv_env("ANSIBLE_SWARM_CACHE_SERVER_EXT_HOSTS")
    cache_ext_tags = csv_env("ANSIBLE_SWARM_CACHE_SERVER_EXT_TAGS")
    cache_int_hosts = csv_env("ANSIBLE_SWARM_CACHE_SERVER_INT_HOSTS")
    cache_int_tags = csv_env("ANSIBLE_SWARM_CACHE_SERVER_INT_TAGS")
    ssh_extra_hosts = csv_env("ANSIBLE_SSH_COPY_ID_EXTRA_HOSTS")
    zabbix_hosts = csv_env("ANSIBLE_ZABBIX_AGENT_HOSTS")

    if cache_ext_tags and len(cache_ext_tags) != len(cache_ext_hosts):
        warn("ANSIBLE_SWARM_CACHE_SERVER_EXT_TAGS count does not match ANSIBLE_SWARM_CACHE_SERVER_EXT_HOSTS")

    if cache_int_tags and len(cache_int_tags) != len(cache_int_hosts):
        warn("ANSIBLE_SWARM_CACHE_SERVER_INT_TAGS count does not match ANSIBLE_SWARM_CACHE_SERVER_INT_HOSTS")

    for index, ip in enumerate(manager_hosts, start=1):
        add_host(inventory, "swarm_managers", f"swarm-manager-{index:02d}", ip)

    for ip in backend_hosts:
        add_host(
            inventory,
            "swarm_backend_workers",
            host_alias("backend", ip),
            ip,
            {"node_tag": "backend"},
        )

    for ip in file_server_hosts:
        add_host(
            inventory,
            "swarm_file_server_workers",
            host_alias("file-server", ip),
            ip,
            {"node_tag": "file-server"},
        )

    for index, ip in enumerate(cache_ext_hosts, start=1):
        tag = cache_ext_tags[index - 1] if index <= len(cache_ext_tags) else f"cache-server-ext-{index:02d}"
        add_host(inventory, "swarm_cache_ext_workers", tag, ip, {"node_tag": tag})

    for index, ip in enumerate(cache_int_hosts, start=1):
        tag = cache_int_tags[index - 1] if index <= len(cache_int_tags) else f"cache-server-int-{index:02d}"
        add_host(inventory, "swarm_cache_int_workers", tag, ip, {"node_tag": tag})

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
    add_children(inventory, "ssh_copy_id_targets", ["swarm_managers", "swarm_workers", "ssh_copy_id_extra_targets"])

    ip_to_alias = {
        hostvars["ansible_host"]: alias
        for alias, hostvars in inventory["_meta"]["hostvars"].items()
    }

    for ip in all_target_hosts:
        alias = ip_to_alias.get(ip, host_alias("target", ip))
        add_host(inventory, "all_targets", alias, ip, advertise=False)

    for ip in zabbix_hosts:
        alias = ip_to_alias.get(ip, host_alias("zabbix-agent", ip))
        add_host(inventory, "zabbix_agent_targets", alias, ip, advertise=False)

    set_group_vars(inventory, "linux", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "zabbix_agent_targets", connection_vars(become=env_bool("ANSIBLE_BECOME", "true")))
    set_group_vars(inventory, "ssh_copy_id_targets", connection_vars(become=False))

    return inventory


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--host":
        print(json.dumps({}))
    else:
        print(json.dumps(build_inventory(), indent=2, sort_keys=True))
