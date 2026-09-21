#!/usr/bin/env python3
"""Recreate one explicitly named Unraid test container from a new image.

The old container is retained under a timestamped rollback name while the new
container starts and completes its health/IP/stability gate. A failed gate
restores the old container automatically. After a successful gate, the old
container and its unreferenced Vibe image are removed by default.
"""

import argparse
import datetime
import json
import pathlib
import re
import subprocess
import sys
import time


PROTECTED_CONTAINERS = {"sagetvopen-sagetv-server-java11"}
ENV_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
VIBE_IMAGE_PREFIXES = (
    "sagetv-vibe-server-u26-gpu-j11:",
    "ghcr.io/opensagetv-vibe/opensagetv-vibe-server:",
)


def run(*args, capture=True, check=True):
    return subprocess.run(
        list(args),
        check=check,
        capture_output=capture,
        text=True,
    )


def inspect_container(name):
    result = run("docker", "inspect", name)
    return json.loads(result.stdout)[0]


def add_many(command, option, values):
    for value in values or []:
        command.extend((option, str(value)))


def add_port_bindings(command, bindings):
    for container_port, host_bindings in (bindings or {}).items():
        for binding in host_bindings or []:
            host_ip = binding.get("HostIp", "")
            host_port = binding.get("HostPort", "")
            target = host_port
            if host_ip:
                target = f"{host_ip}:{host_port}"
            command.extend(("--publish", f"{target}:{container_port}"))


def override_environment(values, overrides):
    """Return the existing Docker environment with explicit values replaced."""
    ordered = []
    positions = {}
    for item in values or []:
        name = item.split("=", 1)[0]
        positions[name] = len(ordered)
        ordered.append(item)
    for item in overrides or []:
        if "=" not in item:
            raise ValueError(f"environment override must be NAME=VALUE: {item}")
        name, _ = item.split("=", 1)
        if not ENV_NAME.fullmatch(name):
            raise ValueError(f"invalid environment variable name: {name}")
        if name in positions:
            ordered[positions[name]] = item
        else:
            positions[name] = len(ordered)
            ordered.append(item)
    return ordered


def create_command(old, name, image, env_file):
    config = old["Config"]
    host = old["HostConfig"]
    networks = old["NetworkSettings"]["Networks"]
    network_name = host.get("NetworkMode") or "bridge"
    endpoint = networks.get(network_name, {})

    command = ["docker", "create", "--name", name, "--env-file", str(env_file)]
    command.extend(("--network", network_name))
    if endpoint.get("IPAddress"):
        command.extend(("--ip", endpoint["IPAddress"]))
    if endpoint.get("GlobalIPv6Address"):
        command.extend(("--ip6", endpoint["GlobalIPv6Address"]))
    if endpoint.get("MacAddress"):
        command.extend(("--mac-address", endpoint["MacAddress"]))

    restart = host.get("RestartPolicy", {})
    restart_name = restart.get("Name")
    if restart_name:
        policy = restart_name
        maximum = restart.get("MaximumRetryCount", 0)
        if restart_name == "on-failure" and maximum:
            policy = f"{restart_name}:{maximum}"
        command.extend(("--restart", policy))
    if host.get("Privileged"):
        command.append("--privileged")
    if host.get("ReadonlyRootfs"):
        command.append("--read-only")
    if host.get("ShmSize"):
        command.extend(("--shm-size", str(host["ShmSize"])))

    add_many(command, "--volume", host.get("Binds"))
    for device in host.get("Devices") or []:
        value = f"{device['PathOnHost']}:{device['PathInContainer']}"
        permissions = device.get("CgroupPermissions")
        if permissions:
            value += f":{permissions}"
        command.extend(("--device", value))
    add_many(command, "--cap-add", host.get("CapAdd"))
    add_many(command, "--cap-drop", host.get("CapDrop"))
    add_many(command, "--dns", host.get("Dns"))
    add_many(command, "--dns-search", host.get("DnsSearch"))
    add_many(command, "--dns-option", host.get("DnsOptions"))
    add_many(command, "--add-host", host.get("ExtraHosts"))
    add_many(command, "--group-add", host.get("GroupAdd"))
    add_many(command, "--security-opt", host.get("SecurityOpt"))

    for key, value in (host.get("Sysctls") or {}).items():
        command.extend(("--sysctl", f"{key}={value}"))
    for key, value in (host.get("Tmpfs") or {}).items():
        command.extend(("--tmpfs", f"{key}:{value}" if value else key))
    add_port_bindings(command, host.get("PortBindings"))

    if config.get("User"):
        command.extend(("--user", config["User"]))
    if config.get("WorkingDir"):
        command.extend(("--workdir", config["WorkingDir"]))
    if config.get("StopSignal"):
        command.extend(("--stop-signal", config["StopSignal"]))
    if config.get("Tty"):
        command.append("--tty")
    if config.get("OpenStdin"):
        command.append("--interactive")

    command.append(image)
    return command


def wait_healthy(name, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        current = inspect_container(name)
        state = current["State"]
        if not state.get("Running"):
            raise RuntimeError(f"replacement exited: {state.get('Error') or state.get('Status')}")
        health = state.get("Health", {}).get("Status")
        if health == "healthy":
            return current
        if health == "unhealthy":
            raise RuntimeError("replacement became unhealthy")
        time.sleep(2)
    raise RuntimeError(f"replacement did not become healthy within {timeout} seconds")


def wait_stably_healthy(name, expected_ip, seconds):
    """Require the replacement to remain healthy at its expected IP."""
    deadline = time.monotonic() + seconds
    current = inspect_container(name)
    while True:
        state = current["State"]
        if not state.get("Running") or state.get("Health", {}).get("Status") != "healthy":
            raise RuntimeError("replacement lost health during the stability gate")
        addresses = [item.get("IPAddress") for item in current["NetworkSettings"]["Networks"].values()]
        if expected_ip not in addresses:
            raise RuntimeError(f"replacement lost expected IP {expected_ip}")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return current
        time.sleep(min(2, remaining))
        current = inspect_container(name)


def image_is_vibe_owned(image):
    tags = image.get("RepoTags") or []
    return all(tag == "<none>:<none>" or tag.startswith(VIBE_IMAGE_PREFIXES) for tag in tags)


def remove_verified_rollback(rollback, active_name, old_image_id):
    """Remove only the verified test rollback and its unreferenced Vibe image."""
    prefix = f"{active_name}-rollback-"
    if not rollback.startswith(prefix):
        raise RuntimeError(f"refusing non-Vibe rollback name: {rollback}")
    rollback_state = inspect_container(rollback)
    if rollback_state["State"].get("Running"):
        raise RuntimeError(f"refusing to remove running rollback: {rollback}")

    active = inspect_container(active_name)
    active_image_id = active.get("Image")
    run("docker", "rm", rollback, capture=False)
    print(f"ROLLBACK REMOVED: {rollback}")

    if not old_image_id or old_image_id == active_image_id:
        return
    references = run(
        "docker", "ps", "--all", "--filter", f"ancestor={old_image_id}", "--quiet"
    ).stdout.strip()
    if references:
        print(f"OLD IMAGE RETAINED (still referenced): {old_image_id}")
        return
    image_result = run("docker", "image", "inspect", old_image_id, check=False)
    if image_result.returncode != 0:
        return
    image = json.loads(image_result.stdout)[0]
    if not image_is_vibe_owned(image):
        raise RuntimeError(f"refusing to remove image with a non-Vibe tag: {old_image_id}")
    run("docker", "image", "rm", old_image_id, capture=False)
    print(f"OLD VIBE IMAGE REMOVED: {old_image_id}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--container", required=True)
    parser.add_argument("--image", required=True)
    parser.add_argument("--expected-ip", required=True)
    parser.add_argument("--backup-dir", required=True)
    parser.add_argument("--health-timeout", type=int, default=180)
    parser.add_argument(
        "--verification-soak-seconds",
        type=int,
        default=30,
        help="continuous healthy/IP stability time before old-container cleanup",
    )
    parser.add_argument(
        "--retain-rollback",
        action="store_true",
        help="explicitly retain the stopped prior container after verification",
    )
    parser.add_argument(
        "--set-env",
        action="append",
        default=[],
        metavar="NAME=VALUE",
        help="replace or add one environment value in the recreated test container",
    )
    args = parser.parse_args()

    if args.verification_soak_seconds < 0:
        raise SystemExit("verification soak seconds must not be negative")

    if args.container in PROTECTED_CONTAINERS:
        raise SystemExit(f"refusing protected container: {args.container}")
    if args.container != "sagetv-vibe-server-u26-gpu-j11":
        raise SystemExit("this commissioning helper is restricted to the Vibe test container")

    old = inspect_container(args.container)
    if old["State"].get("Status") != "running":
        raise SystemExit("test container must be running before replacement")
    current_ips = [item.get("IPAddress") for item in old["NetworkSettings"]["Networks"].values()]
    if args.expected_ip not in current_ips:
        raise SystemExit(f"expected IP {args.expected_ip} not assigned to the test container")
    run("docker", "image", "inspect", args.image)
    old_image_id = old.get("Image")

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    rollback = f"{args.container}-rollback-{stamp}"
    backup_dir = pathlib.Path(args.backup_dir)
    backup_dir.mkdir(parents=True, exist_ok=True)
    inspect_path = backup_dir / f"{rollback}.inspect.json"
    inspect_path.write_text(json.dumps(old, indent=2) + "\n")
    inspect_path.chmod(0o600)
    env_path = backup_dir / f".{rollback}.env"
    environment = override_environment(old["Config"].get("Env"), args.set_env)
    env_path.write_text("\n".join(environment) + "\n")
    env_path.chmod(0o600)

    replacement_created = False
    old_renamed = False
    try:
        run("docker", "stop", "--time", "30", args.container, capture=False)
        run("docker", "rename", args.container, rollback, capture=False)
        old_renamed = True
        command = create_command(old, args.container, args.image, env_path)
        run(*command, capture=False)
        replacement_created = True
        run("docker", "start", args.container, capture=False)
        current = wait_healthy(args.container, args.health_timeout)
        new_ip = next(
            item.get("IPAddress")
            for item in current["NetworkSettings"]["Networks"].values()
            if item.get("IPAddress")
        )
        if new_ip != args.expected_ip:
            raise RuntimeError(f"replacement IP is {new_ip}, expected {args.expected_ip}")
        current = wait_stably_healthy(
            args.container, args.expected_ip, args.verification_soak_seconds
        )
    except Exception:
        if replacement_created:
            run("docker", "rm", "--force", args.container, capture=False, check=False)
        if old_renamed:
            run("docker", "rename", rollback, args.container, capture=False, check=False)
            run("docker", "start", args.container, capture=False, check=False)
        raise
    finally:
        env_path.unlink(missing_ok=True)

    if args.retain_rollback:
        print(f"ROLLBACK RETAINED BY REQUEST: {rollback}")
    else:
        # This runs only after the complete replacement gate. Cleanup failure
        # leaves the verified new container active and makes the task fail for
        # explicit operator attention; it never tears down the good replacement.
        remove_verified_rollback(rollback, args.container, old_image_id)

    print(f"REDEPLOY PASSED: {args.container} is healthy at {args.expected_ip}")
    print(f"INSPECT BACKUP: {inspect_path}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"REDEPLOY FAILED: {error}", file=sys.stderr)
        raise
