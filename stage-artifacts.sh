#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_package="${CORE_PACKAGE:-$root/../opensagetv-vibe-core/output/packages/sagetv-server-x86_64.tar.gz}"
mim_output="${MIM_OUTPUT:-$root/../opensagetv-vibe-ffmpeg-mim/output/linux-x64}"
xmltv_output="${XMLTV_OUTPUT:-$root/../opensagetv-vibe-xmltv-import/output}"
artifacts="$root/artifacts"

required=(
  "$core_package"
  "$mim_output/ffmpeg_MIM"
  "$mim_output/ffmpeg.real"
  "$mim_output/ffprobe"
  "$mim_output/ffmpeg.real.ini"
  "$mim_output/ffmpeg_init.sh"
  "$mim_output/SHA256SUMS.txt"
  "$xmltv_output/packages/XMLTVImportPlugin.jar"
  "$xmltv_output/config-examples/common.properties"
)
for file in "${required[@]}"; do
  test -s "$file" || { echo "ERROR: required runtime artifact is missing: $file" >&2; exit 2; }
done

(cd "$mim_output" && sha256sum -c SHA256SUMS.txt)
gzip -t "$core_package"
unzip -tq "$xmltv_output/packages/XMLTVImportPlugin.jar" >/dev/null

# This directory is generated, ignored by Git, and is the Docker build context's
# only source of compiled component artifacts.
rm -rf "$artifacts"
mkdir -p "$artifacts/ffmpeg-mim" "$artifacts/xmltv/config-examples"
cp "$core_package" "$artifacts/sagetv-server-x86_64.tar.gz"
for name in \
  ffmpeg_MIM ffmpeg.real ffprobe ffmpeg.real.ini ffmpeg_init.sh \
  diagnose_miniplayer.sh diagnose_sagetv_abort.sh hardware_encoders.txt \
  build_report.txt SHA256SUMS.txt; do
  test ! -e "$mim_output/$name" || cp "$mim_output/$name" "$artifacts/ffmpeg-mim/$name"
done
cp "$xmltv_output/packages/XMLTVImportPlugin.jar" "$artifacts/xmltv/"
cp -a "$xmltv_output/config-examples/." "$artifacts/xmltv/config-examples/"

test "$(sha256sum "$core_package" | cut -d' ' -f1)" = \
  "$(sha256sum "$artifacts/sagetv-server-x86_64.tar.gz" | cut -d' ' -f1)"
test "$(sha256sum "$mim_output/ffmpeg_MIM" | cut -d' ' -f1)" = \
  "$(sha256sum "$artifacts/ffmpeg-mim/ffmpeg_MIM" | cut -d' ' -f1)"
test "$(sha256sum "$xmltv_output/packages/XMLTVImportPlugin.jar" | cut -d' ' -f1)" = \
  "$(sha256sum "$artifacts/xmltv/XMLTVImportPlugin.jar" | cut -d' ' -f1)"

echo "RUNTIME ARTIFACT STAGING PASSED"
