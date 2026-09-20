#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
production_image="${OPENSAGETV_VIBE_SERVER_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11}"
debug_image="${OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11-debug}"
core_version="${OPENSAGETV_VIBE_CORE_VERSION:-9.2.10-u26-j11}"
source_revision="$(git -C "$root" rev-parse HEAD)"
core_revision="$(git -C "${CORE_SOURCE:-$root/../opensagetv-vibe-core}" rev-parse HEAD)"
xmltv_revision="$(git -C "${XMLTV_SOURCE:-$root/../opensagetv-vibe-xmltv-import}" rev-parse HEAD)"
previous_production="$(docker image inspect "$production_image" --format '{{.Id}}' 2>/dev/null || true)"
previous_debug="$(docker image inspect "$debug_image" --format '{{.Id}}' 2>/dev/null || true)"
runtime_fingerprint="$(bash "$root/scripts/runtime-environment-fingerprint.sh")"
installed_fingerprint="$(docker image inspect "$production_image" \
  --format '{{index .Config.Labels "org.opensagetv.vibe.runtime-environment.fingerprint"}}' 2>/dev/null || true)"
installed_debug_fingerprint="$(docker image inspect "$debug_image" \
  --format '{{index .Config.Labels "org.opensagetv.vibe.runtime-environment.fingerprint"}}' 2>/dev/null || true)"

if [[ "${FORCE_RUNTIME_IMAGE_BUILD:-false}" != true \
      && -n "$installed_fingerprint" \
      && "$installed_fingerprint" == "$runtime_fingerprint" \
      && "$installed_debug_fingerprint" == "$runtime_fingerprint" ]]; then
  echo "Runtime OS/container environment is unchanged; image rebuild skipped."
  echo "fingerprint=$runtime_fingerprint"
  echo "Use FORCE_RUNTIME_IMAGE_BUILD=true only for an intentional baseline refresh."
  bash "$root/scripts/cleanup-project-docker.sh"
  exit 0
fi

if [[ "${SKIP_ARTIFACT_STAGE:-false}" != true ]]; then
  bash "$root/stage-artifacts.sh"
fi
common_args=(
  --platform linux/amd64
  --build-arg "CORE_VERSION=$core_version"
  --build-arg "SOURCE_REVISION=$source_revision"
  --build-arg "CORE_REVISION=$core_revision"
  --build-arg "XMLTV_REVISION=$xmltv_revision"
  --build-arg "RUNTIME_ENVIRONMENT_FINGERPRINT=$runtime_fingerprint"
  -f "$root/modern/Dockerfile"
)
docker buildx build --load "${common_args[@]}" --target production -t "$production_image" "$root"
docker buildx build --load "${common_args[@]}" --target debug -t "$debug_image" "$root"
current_production="$(docker image inspect "$production_image" --format '{{.Id}}')"
current_debug="$(docker image inspect "$debug_image" --format '{{.Id}}')"
for old in "$previous_production" "$previous_debug"; do
  if [[ -n "$old" && "$old" != "$current_production" && "$old" != "$current_debug" ]]; then
    docker image rm "$old" >/dev/null 2>&1 || true
  fi
done
echo "Container images built"
bash "$root/scripts/cleanup-project-docker.sh"
