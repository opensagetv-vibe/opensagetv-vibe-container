#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
component="${1:-}"
output_dir="${2:-$root/output/component-updates}"
core_source="${CORE_SOURCE:-$root/../opensagetv-vibe-core}"
mim_source="${MIM_SOURCE:-$root/../opensagetv-vibe-ffmpeg-mim}"
xmltv_source="${XMLTV_SOURCE:-$root/../opensagetv-vibe-xmltv-import}"

case "$component" in core|mim|xmltv|comskip) ;; *)
  echo "Usage: $0 {core|mim|xmltv|comskip} [output-directory]" >&2
  exit 2
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/payload" "$output_dir"

case "$component" in
  core)
    source_file="$core_source/output/packages/sagetv-server-x86_64.tar.gz"
    test -s "$source_file"
    gzip -t "$source_file"
    cp "$source_file" "$tmp/payload/core.tar.gz"
    revision="$(git -C "$core_source" rev-parse HEAD)"
    ;;
  mim)
    source_dir="$mim_source/output/linux-x64"
    (cd "$source_dir" && sha256sum -c SHA256SUMS.txt >&2)
    for name in ffmpeg_MIM ffmpeg.real ffprobe ffmpeg.real.ini; do
      test -s "$source_dir/$name"
      cp "$source_dir/$name" "$tmp/payload/$name"
    done
    revision="$(git -C "$mim_source" rev-parse HEAD)"
    ;;
  xmltv)
    source_file="$xmltv_source/output/packages/XMLTVImportPlugin.jar"
    test -s "$source_file"
    unzip -tq "$source_file" >/dev/null
    cp "$source_file" "$tmp/payload/XMLTVImportPlugin.jar"
    revision="$(git -C "$xmltv_source" rev-parse HEAD)"
    ;;
  comskip)
    source_file="$root/sagetv-base/SYSTEM/sagetv_files/comskip/comskip"
    config_file="$root/sagetv-base/SYSTEM/sagetv_files/comskip/comskip.ini"
    test -s "$source_file"
    cp "$source_file" "$tmp/payload/comskip"
    test ! -s "$config_file" || cp "$config_file" "$tmp/payload/comskip.ini.example"
    revision="$(git -C "$root" rev-parse HEAD)"
    ;;
esac

created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$tmp/component.properties" <<EOF
format=opensagetv-vibe-component-update-v1
component=$component
revision=$revision
created_utc=$created
EOF
(cd "$tmp" && find component.properties payload -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
short_revision="${revision:0:12}"
archive="$output_dir/opensagetv-vibe-${component}-${short_revision}.tar.gz"
tar -C "$tmp" -czf "$archive" component.properties SHA256SUMS payload
(cd "$output_dir" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")
echo "$archive"
