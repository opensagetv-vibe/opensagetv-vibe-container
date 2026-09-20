#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
component="${1:-}"
case "$component" in core|xmltv|tmdb|comskip) ;; *)
  echo "Usage: $0 {core|xmltv|tmdb|comskip}" >&2
  exit 2
esac
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
archive="$(bash "$root/scripts/create-component-update.sh" "$component" "$tmp")"
(cd "$tmp" && sha256sum -c "$(basename "$archive").sha256")
tar -tzf "$archive" >/dev/null
case "$component" in
  core) tar -xOzf "$archive" payload/core.tar.gz | gzip -t ;;
  xmltv) tar -xOzf "$archive" payload/XMLTVImportPlugin.jar > "$tmp/plugin.jar"; unzip -tq "$tmp/plugin.jar" >/dev/null ;;
  tmdb)
    tar -xzf "$archive" -C "$tmp" payload
    for name in OpenSageTVVibeTMDB.jar sqlite-jdbc-3.53.2.1.jar gson-2.14.0.jar; do
      unzip -tq "$tmp/payload/JARs/$name" >/dev/null
    done
    test -s "$tmp/payload/plugins/opensagetv-vibe-tmdb/plugin.properties"
    test -s "$tmp/payload/plugins/opensagetv-vibe-tmdb/tmdb_config.example.toml"
    test ! -e "$tmp/payload/plugins/opensagetv-vibe-tmdb/tmdb_config.toml"
    ;;
  comskip) test "$(tar -xOzf "$archive" payload/comskip | wc -c)" -gt 100000 ;;
esac
echo "TARGETED COMPONENT TEST PASSED: $component"
