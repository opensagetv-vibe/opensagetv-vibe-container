#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_package="${CORE_PACKAGE:-$root/../opensagetv-vibe-core/output/packages/sagetv-server-x86_64.tar.gz}"
xmltv_output="${XMLTV_OUTPUT:-$root/../opensagetv-vibe-xmltv-import/output}"
artifacts="$root/artifacts"

required=(
  "$core_package"
  "$xmltv_output/packages/XMLTVImportPlugin.jar"
  "$xmltv_output/config-examples/common.properties"
)
for file in "${required[@]}"; do
  test -s "$file" || { echo "ERROR: required runtime artifact is missing: $file" >&2; exit 2; }
done

gzip -t "$core_package"
unzip -tq "$xmltv_output/packages/XMLTVImportPlugin.jar" >/dev/null

# Compiled runtime payloads are generated and ignored by Git.  Keep the common
# artifacts/downloads handoff area intact when refreshing the Docker context.
rm -rf "$artifacts/ffmpeg-mim" "$artifacts/xmltv"
rm -f "$artifacts/sagetv-server-x86_64.tar.gz"
mkdir -p "$artifacts/downloads" "$artifacts/xmltv/config-examples"
cp "$core_package" "$artifacts/sagetv-server-x86_64.tar.gz"
cp "$xmltv_output/packages/XMLTVImportPlugin.jar" "$artifacts/xmltv/"
cp -a "$xmltv_output/config-examples/." "$artifacts/xmltv/config-examples/"

test "$(sha256sum "$core_package" | cut -d' ' -f1)" = \
  "$(sha256sum "$artifacts/sagetv-server-x86_64.tar.gz" | cut -d' ' -f1)"
test "$(sha256sum "$xmltv_output/packages/XMLTVImportPlugin.jar" | cut -d' ' -f1)" = \
  "$(sha256sum "$artifacts/xmltv/XMLTVImportPlugin.jar" | cut -d' ' -f1)"

echo "RUNTIME ARTIFACT STAGING PASSED"
