#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
(
  cd "$root"
  find modern/Dockerfile modern/rootfs resources -type f -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum
) | sha256sum | cut -d' ' -f1
