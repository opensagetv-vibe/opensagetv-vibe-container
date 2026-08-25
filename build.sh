#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_package="${CORE_PACKAGE:-$root/../opensagetv-core/output/packages/sagetv-server-x86_64.tar.gz}"
test -f "$core_package" || { echo "Missing Core package: $core_package"; exit 2; }
mkdir -p "$root/artifacts"
cp "$core_package" "$root/artifacts/sagetv-server-x86_64.tar.gz"
docker build --target production -t sagetv-server-26-gpu-j11:local -f "$root/modern/Dockerfile" "$root"
docker build --target debug -t sagetv-server-26-gpu-j11:debug-local -f "$root/modern/Dockerfile" "$root"
echo "Container images built"
