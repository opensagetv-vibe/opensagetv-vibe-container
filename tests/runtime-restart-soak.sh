#!/usr/bin/env bash
set -euo pipefail

name="${1:?usage: runtime-restart-soak.sh CONTAINER_NAME}"
cycles="${OPENSAGETV_VIBE_RESTART_CYCLES:-3}"
startup_timeout="${OPENSAGETV_VIBE_RESTART_TIMEOUT_SECONDS:-120}"
stop_timeout="${OPENSAGETV_VIBE_STOP_TIMEOUT_SECONDS:-20}"
settle_seconds="${OPENSAGETV_VIBE_METRIC_SETTLE_SECONDS:-3}"
max_fd_growth="${OPENSAGETV_VIBE_MAX_FD_GROWTH:-64}"
max_thread_growth="${OPENSAGETV_VIBE_MAX_THREAD_GROWTH:-64}"
max_rss_growth_kib="${OPENSAGETV_VIBE_MAX_RSS_GROWTH_KIB:-262144}"

for value in "$cycles" "$startup_timeout" "$stop_timeout" "$settle_seconds" \
  "$max_fd_growth" "$max_thread_growth" "$max_rss_growth_kib"; do
  [[ "$value" =~ ^[0-9]+$ ]] || {
    echo "ERROR: restart-soak settings must be non-negative integers: $value" >&2
    exit 2
  }
done
(( cycles >= 2 )) || {
  echo "ERROR: OPENSAGETV_VIBE_RESTART_CYCLES must be at least 2" >&2
  exit 2
}
(( startup_timeout > 0 && stop_timeout > 0 )) || {
  echo "ERROR: restart and stop timeouts must be greater than zero" >&2
  exit 2
}

wait_for_sagetv() {
  local expected_old_pid="${1:-}" pid="" health=""
  for _ in $(seq 1 "$startup_timeout"); do
    if [[ "$(docker inspect "$name" --format '{{.State.Running}}' 2>/dev/null || true)" != true ]]; then
      docker logs "$name" >&2 || true
      echo "ERROR: $name exited while waiting for SageTV" >&2
      return 1
    fi
    pid="$(docker exec "$name" sh -c 'cat /tmp/sagetv.pid 2>/dev/null || true' | tr -d '\r\n')"
    if [[ "$pid" =~ ^[0-9]+$ ]] && [[ "$pid" != "$expected_old_pid" ]] &&
       docker exec "$name" test -r "/proc/$pid/status" 2>/dev/null &&
       docker exec "$name" sh -c "tr '\\0' ' ' < /proc/$pid/cmdline | grep -q 'sage.Sage'" 2>/dev/null; then
      if python3 - "$name" 2>/dev/null <<'PY'
import socket
import sys

with socket.create_connection((sys.argv[1], 42024), timeout=2):
    pass
PY
      then
        printf '%s\n' "$pid"
        return 0
      fi
    fi
    sleep 1
  done
  health="$(docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null || true)"
  docker logs "$name" >&2 || true
  echo "ERROR: SageTV did not become ready within ${startup_timeout}s (health=$health)" >&2
  return 1
}

wait_for_health() {
  local health=""
  for _ in $(seq 1 "$startup_timeout"); do
    health="$(docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}')"
    [[ "$health" == healthy ]] && return 0
    [[ "$health" != unhealthy ]] || {
      docker logs "$name" >&2 || true
      echo "ERROR: $name became unhealthy" >&2
      return 1
    }
    sleep 1
  done
  echo "ERROR: $name health did not become healthy within ${startup_timeout}s (health=$health)" >&2
  return 1
}

collect_metrics() {
  docker exec "$name" bash -c '
    set -euo pipefail
    pid="$(cat /tmp/sagetv.pid)"
    test -r "/proc/$pid/status"
    tr "\0" " " < "/proc/$pid/cmdline" | grep -q "sage.Sage"
    fds="$(find "/proc/$pid/fd" -mindepth 1 -maxdepth 1 -printf x | wc -c)"
    threads="$(find "/proc/$pid/task" -mindepth 1 -maxdepth 1 -type d -printf x | wc -c)"
    rss="$(awk "/^VmRSS:/ {print \$2}" "/proc/$pid/status")"
    zombies="$(ps -eo stat= | awk '\''BEGIN { count=0 } $1 ~ /^Z/ { count++ } END { print count }'\'')"
    starts="$(grep -c "supervisor: starting SageTV" /opt/sagetv/server/sagetv-supervisor.log || true)"
    printf "%s %s %s %s %s %s\n" "$pid" "$fds" "$threads" "$rss" "$zombies" "$starts"
  '
}

assert_metrics() {
  local label="$1" expected_starts="$2" metrics pid fds threads rss zombies starts
  metrics="$(collect_metrics)"
  read -r pid fds threads rss zombies starts <<<"$metrics"
  [[ "$pid" =~ ^[0-9]+$ && "$fds" =~ ^[0-9]+$ && "$threads" =~ ^[0-9]+$ &&
     "$rss" =~ ^[0-9]+$ && "$zombies" =~ ^[0-9]+$ && "$starts" =~ ^[0-9]+$ ]]
  (( zombies == 0 )) || {
    echo "ERROR: $label left $zombies zombie process(es)" >&2
    return 1
  }
  (( starts >= expected_starts )) || {
    echo "ERROR: $label did not produce the expected supervisor start (starts=$starts expected>=$expected_starts)" >&2
    return 1
  }
  if [[ -n "${baseline_fds:-}" ]]; then
    (( fds <= baseline_fds + max_fd_growth )) || {
      echo "ERROR: $label file descriptors grew from $baseline_fds to $fds" >&2
      return 1
    }
    (( threads <= baseline_threads + max_thread_growth )) || {
      echo "ERROR: $label threads grew from $baseline_threads to $threads" >&2
      return 1
    }
    (( rss <= baseline_rss + max_rss_growth_kib )) || {
      echo "ERROR: $label RSS grew from ${baseline_rss}KiB to ${rss}KiB" >&2
      return 1
    }
  fi
  printf '[PASS] %s pid=%s fds=%s threads=%s rss_kib=%s zombies=%s supervisor_starts=%s\n' \
    "$label" "$pid" "$fds" "$threads" "$rss" "$zombies" "$starts"
  METRIC_PID="$pid" METRIC_FDS="$fds" METRIC_THREADS="$threads" METRIC_RSS="$rss" METRIC_STARTS="$starts"
}

test "$(docker exec "$name" ps -p 1 -o comm= | tr -d '[:space:]')" = tini
wait_for_health
sleep "$settle_seconds"
baseline_fds="" baseline_threads="" baseline_rss=""
assert_metrics baseline 1
baseline_pid="$METRIC_PID" baseline_fds="$METRIC_FDS"
baseline_threads="$METRIC_THREADS" baseline_rss="$METRIC_RSS"
baseline_starts="$METRIC_STARTS"

# Exercise the in-container supervisor independently of Docker restart policy.
docker exec "$name" kill -TERM "$baseline_pid"
wait_for_sagetv "$baseline_pid" >/dev/null
sleep "$settle_seconds"
assert_metrics supervisor-child-restart "$((baseline_starts + 1))"

for cycle in $(seq 1 "$cycles"); do
  docker restart --time "$stop_timeout" "$name" >/dev/null
  wait_for_sagetv >/dev/null
  wait_for_health
  sleep "$settle_seconds"
  assert_metrics "container-restart-$cycle" "$((baseline_starts + 1 + cycle))"
done

echo "RUNTIME RESTART SOAK PASSED: supervisor restart + $cycles container restarts"
