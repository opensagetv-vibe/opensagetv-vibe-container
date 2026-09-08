#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
selected="${1:-all}"
case "$selected" in all|mim|tmdb) ;; *) echo "Usage: $0 [all|mim|tmdb]" >&2; exit 2;; esac
mim_source="${MIM_SOURCE:-$root/../opensagetv-vibe-ffmpeg-mim}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/appdata/server" "$tmp/output"
if [[ "$selected" == all || "$selected" == mim ]]; then
printf old > "$tmp/appdata/server/ffmpeg"
printf stock > "$tmp/appdata/server/ffmpeg.stock"
archive="$(bash "$root/scripts/create-component-update.sh" mim "$tmp/output")"
test -s "$archive" && test -s "$archive.sha256"
NO_RESTART=true bash "$root/scripts/install-component-update.sh" "$archive" "$tmp/appdata" unused
cmp -s "$tmp/appdata/server/ffmpeg" "$mim_source/output/linux-x64/ffmpeg_MIM"
test -s "$tmp/appdata/.installed-components/mim.properties"
backup="$(find "$tmp/appdata/.component-backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
NO_RESTART=true bash "$root/scripts/rollback-component-update.sh" "$backup" "$tmp/appdata" unused
grep -qx old "$tmp/appdata/server/ffmpeg"
echo "COMPONENT UPDATE SELFTEST PASSED"
fi

if [[ "$selected" == all || "$selected" == tmdb ]]; then
tmdb_source="${TMDB_SOURCE:-$root/../opensagetv-vibe-tmdb}"
mkdir -p "$tmp/appdata/server/JARs" "$tmp/appdata/server/plugins/opensagetv-vibe-tmdb"
printf 'private-fixture-marker\n' > "$tmp/appdata/server/plugins/opensagetv-vibe-tmdb/tmdb_config.toml"
tmdb_archive="$(TMDB_SOURCE="$tmdb_source" bash "$root/scripts/create-component-update.sh" tmdb "$tmp/output")"
NO_RESTART=true bash "$root/scripts/install-component-update.sh" "$tmdb_archive" "$tmp/appdata" unused
for name in OpenSageTVVibeTMDB.jar sqlite-jdbc-3.53.2.1.jar gson-2.14.0.jar; do
  cmp -s "$tmp/appdata/server/JARs/$name" "$tmdb_source/output/packages/$name"
done
grep -qx 'private-fixture-marker' "$tmp/appdata/server/plugins/opensagetv-vibe-tmdb/tmdb_config.toml"
test -s "$tmp/appdata/.installed-components/tmdb.properties"
tmdb_backup="$(find "$tmp/appdata/.component-backups" -mindepth 1 -maxdepth 1 -type d -name 'tmdb-*' -print -quit)"
NO_RESTART=true bash "$root/scripts/rollback-component-update.sh" "$tmdb_backup" "$tmp/appdata" unused
test ! -e "$tmp/appdata/server/JARs/OpenSageTVVibeTMDB.jar"
grep -qx 'private-fixture-marker' "$tmp/appdata/server/plugins/opensagetv-vibe-tmdb/tmdb_config.toml"
echo "TMDB COMPONENT UPDATE SELFTEST PASSED"
fi
