#!/usr/bin/env bash
set -euo pipefail

archive="${1:-}"
appdata="${2:-/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11}"
container="${3:-sagetv-vibe-server-u26-gpu-j11}"
[[ -f "$archive" ]] || { echo "Usage: $0 UPDATE.tar.gz [appdata-root] [container-name]" >&2; exit 2; }
[[ "$appdata" = /* && "$appdata" != / && "$appdata" != /mnt && "$appdata" != /mnt/user ]] \
  || { echo "ERROR: unsafe appdata target: $appdata" >&2; exit 2; }

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  echo "ERROR: unsafe path in update archive" >&2
  exit 3
fi
tar -xzf "$archive" -C "$tmp"
(cd "$tmp" && sha256sum -c SHA256SUMS)
grep -qx 'format=opensagetv-vibe-component-update-v1' "$tmp/component.properties"
component="$(sed -n 's/^component=//p' "$tmp/component.properties")"
case "$component" in core|xmltv|tmdb|comskip) ;; *) echo "ERROR: invalid component metadata" >&2; exit 3;; esac

server="$appdata/server"
[[ -d "$server" ]] || { echo "ERROR: SageTV server appdata not found: $server" >&2; exit 4; }
timestamp="$(date -u +%Y%m%d-%H%M%S)"
backup="$appdata/.component-backups/$component-$timestamp"
mkdir -p "$backup/current" "$appdata/.installed-components"
: > "$backup/NEW_FILES"
: > "$backup/INSTALLED_FILES"
cp "$tmp/component.properties" "$backup/"
sha256sum "$archive" > "$backup/UPDATE_ARCHIVE.sha256"
metadata_target="$appdata/.installed-components/$component.properties"
if [[ -e "$metadata_target" ]]; then
  cp -a "$metadata_target" "$backup/previous-component.properties"
else
  : > "$backup/REMOVE_COMPONENT_METADATA"
fi

was_running=false
if [[ "${NO_RESTART:-false}" != true ]] && docker inspect "$container" >/dev/null 2>&1; then
  if [[ "$(docker inspect "$container" --format '{{.State.Running}}')" == true ]]; then
    was_running=true
  fi
  # Mark this as a same-image appdata override before stopping. The entrypoint
  # will then preserve it on restart instead of restoring its baseline asset.
  image_marker="/usr/local/share/sagetv-options/.seed-ids/$component.sha256"
  if docker exec "$container" test -s "$image_marker" >/dev/null 2>&1; then
    docker exec "$container" cat "$image_marker" > "$appdata/.image-seeds/$component.sha256"
  fi
  [[ "$was_running" == false ]] || docker stop -t "${STOP_TIMEOUT_SECONDS:-30}" "$container" >/dev/null
elif [[ "${NO_RESTART:-false}" != true ]]; then
  echo "ERROR: container not found: $container" >&2
  exit 4
fi

rollback_needed=true
rollback() {
  local relative
  [[ "$rollback_needed" == true ]] || return 0
  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    rm -f -- "$appdata/$relative"
  done < "$backup/NEW_FILES"
  if [[ -d "$backup/current" ]]; then
    cp -a "$backup/current/." "$appdata/"
  fi
  if [[ -f "$backup/previous-component.properties" ]]; then
    cp -a "$backup/previous-component.properties" "$metadata_target"
  elif [[ -f "$backup/REMOVE_COMPONENT_METADATA" ]]; then
    rm -f -- "$metadata_target"
  fi
  [[ "$was_running" == false ]] || docker start "$container" >/dev/null 2>&1 || true
}
trap 'rc=$?; rollback; cleanup; exit $rc' ERR

install_file() {
  local source="$1" target="$2" mode="${3:-}"
  [[ "$target" == "$appdata/"* ]] || { echo "ERROR: install target escaped appdata: $target" >&2; return 1; }
  local relative="${target#"$appdata/"}"
  mkdir -p "$(dirname "$target")" "$backup/current/$(dirname "$relative")"
  if [[ -e "$target" || -L "$target" ]]; then
    cp -a "$target" "$backup/current/$relative"
  else
    printf '%s\n' "$relative" >> "$backup/NEW_FILES"
  fi
  local staged="$target.update-$$"
  cp -a "$source" "$staged"
  [[ -z "$mode" ]] || chmod "$mode" "$staged"
  mv -f "$staged" "$target"
  printf '%s\n' "$relative" >> "$backup/INSTALLED_FILES"
}

case "$component" in
  core)
    core_stage="$tmp/core"
    mkdir -p "$core_stage"
    gzip -t "$tmp/payload/core.tar.gz"
    tar -xzf "$tmp/payload/core.tar.gz" -C "$core_stage"
    while IFS= read -r -d '' source; do
      relative="${source#"$core_stage/"}"
      case "$relative" in
        Wiz.bin|Wiz.bak|Wiz.bin.*|Sage.properties|SageTVPlugins.xml|filetracker.properties|ffmpeg) continue ;;
      esac
      install_file "$source" "$server/$relative"
    done < <(find "$core_stage" \( -type f -o -type l \) -print0)
    if [[ -f "$core_stage/ffmpeg" ]]; then
      install_file "$core_stage/ffmpeg" "$server/ffmpeg.stock" 0755
    fi
    ;;
  xmltv)
    install_file "$tmp/payload/XMLTVImportPlugin.jar" "$server/JARs/XMLTVImportPlugin.jar" 0644
    ;;
  tmdb)
    for name in OpenSageTVVibeTMDB.jar sqlite-jdbc-3.53.2.1.jar gson-2.14.0.jar; do
      install_file "$tmp/payload/JARs/$name" "$server/JARs/$name" 0644
    done
    plugin_dir="$server/plugins/opensagetv-vibe-tmdb"
    install_file "$tmp/payload/plugins/opensagetv-vibe-tmdb/plugin.properties" \
      "$plugin_dir/plugin.properties" 0644
    install_file "$tmp/payload/plugins/opensagetv-vibe-tmdb/tmdb_config.example.toml" \
      "$plugin_dir/tmdb_config.example.toml" 0644
    # The private tmdb_config.toml is administrator-owned and is deliberately
    # absent from the update package and install targets.
    ;;
  comskip)
    install_file "$tmp/payload/comskip" "$appdata/comskip/comskip" 0755
    if [[ ! -e "$appdata/comskip/comskip.ini" && -s "$tmp/payload/comskip.ini.example" ]]; then
      install_file "$tmp/payload/comskip.ini.example" "$appdata/comskip/comskip.ini" 0644
    fi
    ;;
esac

archive_hash="$(sha256sum "$archive" | cut -d' ' -f1)"
metadata_tmp="$metadata_target.update-$$"
cat "$tmp/component.properties" > "$metadata_tmp"
printf 'archive_sha256=%s\ninstalled_utc=%s\nbackup=%s\n' \
  "$archive_hash" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$backup" >> "$metadata_tmp"
mv -f "$metadata_tmp" "$metadata_target"

if [[ "$was_running" == true ]]; then
  docker start "$container" >/dev/null
  ready=false
  for _ in $(seq 1 "${START_TIMEOUT_SECONDS:-120}"); do
    if docker exec "$container" pgrep -f 'java.*sage.Sage' >/dev/null 2>&1; then ready=true; break; fi
    [[ "$(docker inspect "$container" --format '{{.State.Running}}')" == true ]] || break
    sleep 1
  done
  [[ "$ready" == true ]] || { echo "ERROR: SageTV did not restart after $component update" >&2; exit 5; }
fi

rollback_needed=false
trap - ERR
echo "COMPONENT UPDATE PASSED: $component"
echo "Backup: $backup"
