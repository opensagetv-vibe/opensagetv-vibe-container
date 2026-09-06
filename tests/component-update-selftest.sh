#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mim_source="${MIM_SOURCE:-$root/../opensagetv-vibe-ffmpeg-mim}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/appdata/server" "$tmp/output"
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
