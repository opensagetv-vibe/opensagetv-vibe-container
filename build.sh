#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_package="${CORE_PACKAGE:-$root/../opensagetv-vibe-core/output/packages/sagetv-server-x86_64.tar.gz}"
production_image="${OPENSAGETV_VIBE_SERVER_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11}"
debug_image="${OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11-debug}"
test -f "$core_package" || { echo "Missing Core package: $core_package"; exit 2; }
mkdir -p "$root/artifacts"
cp "$core_package" "$root/artifacts/sagetv-server-x86_64.tar.gz"
docker build --target production -t "$production_image" -f "$root/modern/Dockerfile" "$root"
docker build --target debug -t "$debug_image" -f "$root/modern/Dockerfile" "$root"
echo "Container images built"
