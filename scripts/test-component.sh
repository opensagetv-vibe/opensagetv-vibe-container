#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
component="${1:-}"
case "$component" in core|mim|xmltv|comskip) ;; *)
  echo "Usage: $0 {core|mim|xmltv|comskip}" >&2
  exit 2
esac
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
archive="$(bash "$root/scripts/create-component-update.sh" "$component" "$tmp")"
(cd "$tmp" && sha256sum -c "$(basename "$archive").sha256")
tar -tzf "$archive" >/dev/null
case "$component" in
  core) tar -xOzf "$archive" payload/core.tar.gz | gzip -t ;;
  mim)
    tar -xzf "$archive" -C "$tmp" payload
    chmod 0755 "$tmp/payload/ffmpeg_MIM" "$tmp/payload/ffmpeg.real" "$tmp/payload/ffprobe"
    (cd "$tmp/payload" && ./ffmpeg_MIM --mim-status >/dev/null)
    ;;
  xmltv) tar -xOzf "$archive" payload/XMLTVImportPlugin.jar > "$tmp/plugin.jar"; unzip -tq "$tmp/plugin.jar" >/dev/null ;;
  comskip) test "$(tar -xOzf "$archive" payload/comskip | wc -c)" -gt 100000 ;;
esac
echo "TARGETED COMPONENT TEST PASSED: $component"
