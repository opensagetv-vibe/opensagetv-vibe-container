#!/usr/bin/env bash
set -euo pipefail

run_case() {
  local label="$1" initial_property="$2" work launcher found=0
  work="$(mktemp -d)"
  mkdir -p "$work/JARs"
  cp -a /usr/local/share/sagetv-dist/. "$work/"
  cp /usr/local/share/sagetv-options/xmltv/XMLTVImportPlugin.jar "$work/JARs/"
  if [[ -n "$initial_property" ]]; then
    printf '%s\n' "$initial_property" > "$work/Sage.properties"
  else
    : > "$work/Sage.properties"
  fi

  (
    cd "$work"
    export HEADLESS=true PIDFILE="$work/sagetv.pid" LD_LIBRARY_PATH="$work"
    ./startsagecore > "$work/launch.log" 2>&1
  ) &
  launcher=$!

  for _ in $(seq 1 30); do
    if grep -q '^epg/epg_import_plugin=xmltv.XMLTVImportPlugin$' "$work/Sage.properties" 2>/dev/null; then
      found=1
      break
    fi
    sleep 1
  done

  if [[ -s "$work/sagetv.pid" ]]; then
    kill "$(cat "$work/sagetv.pid")" 2>/dev/null || true
  fi
  kill "$launcher" 2>/dev/null || true
  wait "$launcher" 2>/dev/null || true

  if [[ "$found" != 1 ]]; then
    echo "[FAIL] $label" >&2
    cat "$work/launch.log" >&2
    return 1
  fi
  echo "[PASS] $label"
}

run_case "Core discovers installed XMLTV JAR with no EPG property" ""
run_case "Core replaces an invalid legacy importer with installed XMLTV" \
  "epg/epg_import_plugin=invalid.LegacyImporter"
echo "CORE XMLTV AUTODISCOVERY TEST PASSED"
