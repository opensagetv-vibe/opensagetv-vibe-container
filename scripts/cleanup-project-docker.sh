#!/usr/bin/env bash
set -euo pipefail

# Remove only stopped containers and dangling image layers proven to originate
# from this repository. A global image/container prune is deliberately avoided.
removed=0
while :; do
  candidates=()
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    source_label="$(docker image inspect "$id" --format '{{index .Config.Labels "org.opencontainers.image.source"}}' 2>/dev/null || true)"
    history="$(docker history --no-trunc --format '{{.CreatedBy}}' "$id" 2>/dev/null || true)"
    if [[ "$source_label" == *opensagetv-vibe* ]] \
        || grep -Eq 'ARG (CORE|MIM|XMLTV|SOURCE)_REVISION=unknown|ARG CORE_VERSION=9\.2\.10-u26-dev|/usr/local/share/sagetv|sagetv-entrypoint|libmfx-gen1\.2.*openjdk-11-jre-headless' <<<"$history"; then
      candidates+=("$id")
    fi
  done < <(docker image ls --filter dangling=true --quiet | sort -u)
  ((${#candidates[@]} > 0)) || break

  for id in "${candidates[@]}"; do
    while IFS= read -r container; do
      [[ -n "$container" ]] || continue
      running="$(docker inspect "$container" --format '{{.State.Running}}')"
      if [[ "$running" == false ]]; then
        docker rm "$container" >/dev/null
        echo "Removed stopped Vibe build container: $container"
      fi
    done < <(docker ps --all --filter "ancestor=$id" --quiet)
    if docker image rm "$id" >/dev/null 2>&1; then
      echo "Removed dangling Vibe image: $id"
      removed=$((removed + 1))
    fi
  done
done
echo "Vibe Docker cleanup complete; dangling images removed: $removed"
