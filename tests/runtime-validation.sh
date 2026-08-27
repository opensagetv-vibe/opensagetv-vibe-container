#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core_source="${CORE_SOURCE:-$root/../opensagetv-vibe-core}"
mim_source="${MIM_SOURCE:-$root/../opensagetv-vibe-ffmpeg-mim}"
xmltv_source="${XMLTV_SOURCE:-$root/../opensagetv-vibe-xmltv-import}"
production_image="${OPENSAGETV_VIBE_SERVER_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11}"
debug_image="${OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE:-ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11-debug}"
suffix="${OPENSAGETV_VIBE_TEST_SUFFIX:-$$}"
name="opensagetv-vibe-runtime-test-$suffix"
network="opensagetv-vibe-runtime-test-net-$suffix"
volume="opensagetv-vibe-runtime-test-data-$suffix"
label="org.opensagetv.vibe.test=runtime-validation"
dev_id="${OPENSAGETV_VIBE_DEV_ID:-$(hostname)}"
attached=0

cleanup() {
  docker rm -f -v "$name" >/dev/null 2>&1 || true
  if (( attached )); then docker network disconnect -f "$network" "$dev_id" >/dev/null 2>&1 || true; fi
  docker network rm "$network" >/dev/null 2>&1 || true
  docker volume rm -f "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker image inspect "$production_image" >/dev/null
docker image inspect "$debug_image" >/dev/null
test "$(docker image inspect "$production_image" --format '{{.Os}}/{{.Architecture}}')" = linux/amd64
test "$(docker image inspect "$debug_image" --format '{{.Os}}/{{.Architecture}}')" = linux/amd64
docker image inspect "$production_image" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -qx 'MIM_ENABLED=false'
docker image inspect "$production_image" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -qx 'HARDWARE_DECODE=true'
docker image inspect "$debug_image" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -qx 'SAGETV_DEBUG_IMAGE=true'

for pair in \
  "org.opencontainers.image.revision=$(git -C "$root" rev-parse HEAD)" \
  "org.opensagetv.vibe.core.revision=$(git -C "$core_source" rev-parse HEAD)" \
  "org.opensagetv.vibe.ffmpeg-mim.revision=$(git -C "$mim_source" rev-parse HEAD)" \
  "org.opensagetv.vibe.xmltv-import.revision=$(git -C "$xmltv_source" rev-parse HEAD)"; do
  key="${pair%%=*}"; expected="${pair#*=}"
  test "$(docker image inspect "$production_image" --format "{{index .Config.Labels \"$key\"}}")" = "$expected"
done

docker run --rm --entrypoint bash "$debug_image" -lc \
  'command -v gdb >/dev/null && command -v strace >/dev/null && test -f /usr/local/share/sagetv-dist/Sage.jar && test -s /usr/local/share/sagetv-options/xmltv/XMLTVImportPlugin.jar'

python3 - "$root/unRAID/opensagetv-vibe/sagetv-vibe-server-u26-gpu-j11.xml" "$production_image" <<'PY'
import sys
import xml.etree.ElementTree as ET
path, expected_image = sys.argv[1:]
tree = ET.parse(path)
root = tree.getroot()
assert root.findtext("Name") == "sagetv-vibe-server-u26-gpu-j11"
assert root.findtext("Repository") == expected_image
assert root.findtext("Network") == "br0"
configs = {(node.attrib.get("Name"), node.attrib.get("Target")) for node in root.findall("Config")}
for required in {
    ("SageTV Appdata Path", "/opt/sagetv"),
    ("Hardware Decode", "HARDWARE_DECODE"),
    ("Enable FFmpeg/MIM", "MIM_ENABLED"),
    ("Discovery 31100", "31100"),
}:
    assert required in configs, required
print("[PASS] Unraid CA XML parses and targets the canonical image")
PY

docker network create --label "$label" "$network" >/dev/null
docker volume create --label "$label" "$volume" >/dev/null
docker network connect "$network" "$dev_id"
attached=1
docker run -d --name "$name" --network "$network" --label "$label" \
  -e PUID=0 -e PGID=0 -e JAVA_MEM_MB=512 -e OPT_GENTUNER=N -e OPT_COMSKIP=N \
  --mount "type=volume,source=$volume,target=/opt/sagetv" \
  "$production_image" >/dev/null

started=0
for _ in $(seq 1 120); do
  if docker exec "$name" pgrep -f 'java.*sage.Sage' >/dev/null 2>&1; then started=1; break; fi
  test "$(docker inspect "$name" --format '{{.State.Running}}')" = true || {
    docker logs "$name" >&2; echo "ERROR: runtime container exited during startup" >&2; exit 1;
  }
  sleep 1
done
test "$started" = 1 || { docker logs "$name" >&2; echo "ERROR: SageTV did not start" >&2; exit 1; }

health=starting
for _ in $(seq 1 120); do
  health="$(docker inspect "$name" --format '{{.State.Health.Status}}')"
  [[ "$health" == healthy ]] && break
  [[ "$health" != unhealthy ]] || { docker logs "$name" >&2; exit 1; }
  sleep 1
done
test "$health" = healthy

docker exec "$name" test -f /opt/sagetv/server/Sage.jar
docker exec "$name" test -s /opt/sagetv/server/JARs/XMLTVImportPlugin.jar
docker exec "$name" test -s /opt/sagetv/server/common.properties
docker exec "$name" test -s /opt/sagetv/server/xmltv_EPG123.profile
docker exec "$name" grep -q '^epg/epg_import_plugin=xmltv.XMLTVImportPlugin$' /opt/sagetv/server/Sage.properties
runtime_ip="$(docker inspect "$name" --format "{{with index .NetworkSettings.Networks \"$network\"}}{{.IPAddress}}{{end}}")"
test -n "$runtime_ip"
docker exec "$name" grep -qx "mini_discovery_bind_address=$runtime_ip" /opt/sagetv/server/Sage.properties

python3 - "$name" <<'PY'
import socket
import sys
host = sys.argv[1]
address = socket.gethostbyname(host)
request = bytearray(32)
request[0:4] = b"STV\x01"
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
    udp.settimeout(10)
    udp.sendto(request, (address, 31100))
    response, source = udp.recvfrom(512)
assert source[0] == address, (source, address)
assert len(response) == 15, len(response)
assert response[0:4] == b"STV\x02", response[0:4]
assert int.from_bytes(response[13:15], "big") == 31099
with socket.create_connection((address, 42024), timeout=10):
    pass
print("[PASS] SageTV UDP discovery and TCP service from an independent network peer")
PY

docker cp "$root/tests/core-xmltv-autodiscovery.sh" "$name:/tmp/core-xmltv-autodiscovery.sh"
docker exec "$name" bash /tmp/core-xmltv-autodiscovery.sh
python3 "$root/tests/opendct-integration-test.py" "$core_source" "$root"

bash "$root/tests/runtime-restart-soak.sh" "$name"

docker stop --time 20 "$name" >/dev/null
test "$(docker inspect "$name" --format '{{.State.ExitCode}}')" = 0
cleanup
trap - EXIT

test -z "$(docker ps -aq --filter "label=$label")"
test -z "$(docker network ls -q --filter "label=$label")"
test -z "$(docker volume ls -q --filter "label=$label")"
echo "RUNTIME CONTAINER VALIDATION PASSED"
