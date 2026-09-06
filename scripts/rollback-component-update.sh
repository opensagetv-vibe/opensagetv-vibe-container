#!/usr/bin/env bash
set -euo pipefail

backup="${1:-}"
appdata="${2:-/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11}"
container="${3:-sagetv-vibe-server-u26-gpu-j11}"
[[ -d "$backup/current" && -f "$backup/NEW_FILES" ]] \
  || { echo "Usage: $0 BACKUP-DIRECTORY [appdata-root] [container-name]" >&2; exit 2; }
[[ "$appdata" = /* && "$appdata" != / && "$appdata" != /mnt && "$appdata" != /mnt/user ]] \
  || { echo "ERROR: unsafe appdata target: $appdata" >&2; exit 2; }

was_running=false
if [[ "${NO_RESTART:-false}" != true ]] \
    && docker inspect "$container" >/dev/null 2>&1 \
    && [[ "$(docker inspect "$container" --format '{{.State.Running}}')" == true ]]; then
  was_running=true
  docker stop -t "${STOP_TIMEOUT_SECONDS:-30}" "$container" >/dev/null
fi
while IFS= read -r relative; do
  [[ -n "$relative" ]] || continue
  target="$appdata/$relative"
  [[ "$target" == "$appdata/"* ]] || { echo "ERROR: unsafe rollback target" >&2; exit 3; }
  rm -f -- "$target"
done < "$backup/NEW_FILES"
cp -a "$backup/current/." "$appdata/"
component="$(sed -n 's/^component=//p' "$backup/component.properties" 2>/dev/null || true)"
case "$component" in
  core|mim|xmltv|comskip)
    metadata="$appdata/.installed-components/$component.properties"
    if [[ -f "$backup/previous-component.properties" ]]; then
      mkdir -p "$(dirname "$metadata")"
      cp -a "$backup/previous-component.properties" "$metadata"
    elif [[ -f "$backup/REMOVE_COMPONENT_METADATA" ]]; then
      rm -f -- "$metadata"
    fi
    ;;
esac
[[ "$was_running" == false ]] || docker start "$container" >/dev/null
echo "COMPONENT ROLLBACK PASSED: $backup"
