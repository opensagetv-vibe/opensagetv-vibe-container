#!/usr/bin/env bash
set -euo pipefail

appdata="${1:-/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11}"
container="${2:-sagetv-vibe-server-u26-gpu-j11}"
[[ -d "$appdata/server" ]] || { echo "ERROR: appdata not found: $appdata" >&2; exit 2; }
echo "Installed component metadata"
for metadata in "$appdata"/.installed-components/*.properties; do
  [[ -f "$metadata" ]] || continue
  echo "--- $(basename "$metadata")"
  cat "$metadata"
done
echo "Active artifact SHA-256"
for file in \
  "$appdata/server/Sage.jar" \
  "$appdata/server/ffmpeg" \
  "$appdata/server/SageTVTranscoder" \
  "$appdata/server/plugins/SageTVFFmpegPlugin/runtime/ffmpeg_MIM" \
  "$appdata/server/plugins/SageTVFFmpegPlugin/runtime/ffmpeg.real" \
  "$appdata/server/plugins/SageTVFFmpegPlugin/runtime/ffprobe" \
  "$appdata/server/plugins/SageTVFFmpegPlugin/runtime/ffmpeg.real.ini" \
  "$appdata/server/JARs/XMLTVImportPlugin.jar" \
  "$appdata/server/JARs/OpenSageTVVibeCoreMCPPlugin.jar" \
  "$appdata/server/JARs/OpenSageTVVibeTMDB.jar" \
  "$appdata/server/JARs/sqlite-jdbc-3.53.2.1.jar" \
  "$appdata/server/JARs/gson-2.14.0.jar" \
  "$appdata/comskip/comskip"; do
  [[ ! -f "$file" ]] || sha256sum "$file"
done
if docker inspect "$container" >/dev/null 2>&1; then
  docker ps -a --filter "name=^/${container}$" --format 'Container={{.Names}} Image={{.Image}} Status={{.Status}}'
  if [[ "$(docker inspect "$container" --format '{{.State.Running}}')" == true ]] \
      && [[ -x "$appdata/server/SageTVTranscoder" ]]; then
    docker exec "$container" /opt/sagetv/server/SageTVTranscoder --mim-status || true
  fi
fi
