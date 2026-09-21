#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_package="${CORE_PACKAGE:-$root/../opensagetv-vibe-core/output/packages/sagetv-server-x86_64.tar.gz}"
xmltv_output="${XMLTV_OUTPUT:-$root/../opensagetv-vibe-xmltv-import/output}"
core_mcp_output="${CORE_MCP_OUTPUT:-$root/../opensagetv-vibe-core-MCP-Plugin/output}"
core_mcp_source="${CORE_MCP_SOURCE:-$root/../opensagetv-vibe-core-MCP-Plugin}"
core_mcp_version="$(sed -n 's/^VERSION=//p' "$core_mcp_source/release.properties")"
core_mcp_package="$core_mcp_output/packages/OpenSageTVVibeCoreMCPPlugin-jar-$core_mcp_version.zip"
artifacts="$root/artifacts"

required=(
  "$core_package"
  "$xmltv_output/packages/XMLTVImportPlugin.jar"
  "$xmltv_output/config-examples/common.properties"
  "$core_mcp_package"
)
for file in "${required[@]}"; do
  test -s "$file" || { echo "ERROR: required runtime artifact is missing: $file" >&2; exit 2; }
done

gzip -t "$core_package"
unzip -tq "$xmltv_output/packages/XMLTVImportPlugin.jar" >/dev/null
unzip -tq "$core_mcp_package" >/dev/null

# Compiled runtime payloads are generated and ignored by Git.  Keep the common
# artifacts/downloads handoff area intact when refreshing the Docker context.
rm -rf "$artifacts/ffmpeg-mim" "$artifacts/xmltv" "$artifacts/core-mcp"
rm -f "$artifacts/sagetv-server-x86_64.tar.gz"
mkdir -p "$artifacts/downloads" "$artifacts/xmltv/config-examples" "$artifacts/core-mcp"
cp "$core_package" "$artifacts/sagetv-server-x86_64.tar.gz"
cp "$xmltv_output/packages/XMLTVImportPlugin.jar" "$artifacts/xmltv/"
cp -a "$xmltv_output/config-examples/." "$artifacts/xmltv/config-examples/"
unzip -p "$core_mcp_package" \
  OpenSageTVVibeCoreMCPPlugin.jar > "$artifacts/core-mcp/OpenSageTVVibeCoreMCPPlugin.jar"
printf '%s\n' "$core_mcp_version" > "$artifacts/core-mcp/VERSION"

test "$(sha256sum "$core_package" | cut -d' ' -f1)" = \
  "$(sha256sum "$artifacts/sagetv-server-x86_64.tar.gz" | cut -d' ' -f1)"
test "$(sha256sum "$xmltv_output/packages/XMLTVImportPlugin.jar" | cut -d' ' -f1)" = \
  "$(sha256sum "$artifacts/xmltv/XMLTVImportPlugin.jar" | cut -d' ' -f1)"
unzip -tq "$artifacts/core-mcp/OpenSageTVVibeCoreMCPPlugin.jar" >/dev/null

echo "RUNTIME ARTIFACT STAGING PASSED"
