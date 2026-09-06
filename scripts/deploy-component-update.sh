#!/usr/bin/env bash
set -euo pipefail

archive="${1:-}"
host="${2:-${UNRAID_HOST:-}}"
key="${3:-${UNRAID_SSH_KEY:-}}"
container="${SAGETV_CONTAINER:-sagetv-vibe-server-u26-gpu-j11}"
appdata="${SAGETV_APPDATA:-/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11}"
[[ -f "$archive" && -n "$host" ]] || {
  echo "Usage: $0 UPDATE.tar.gz UNRAID_HOST [SSH_KEY]" >&2
  exit 2
}
ssh_args=(-o BatchMode=yes)
[[ -z "$key" ]] || ssh_args+=(-i "$key")
remote_dir="$appdata/.component-staging/remote"
ssh "${ssh_args[@]}" "root@$host" "mkdir -p '$remote_dir'"
scp "${ssh_args[@]}" "$archive" "$archive.sha256" \
  "$(dirname "$0")/install-component-update.sh" \
  "root@$host:$remote_dir/"
name="$(basename "$archive")"
ssh "${ssh_args[@]}" "root@$host" \
  "cd '$remote_dir' && sha256sum -c '$name.sha256' && bash install-component-update.sh '$name' '$appdata' '$container'"
