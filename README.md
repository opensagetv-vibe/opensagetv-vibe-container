# OpenSageTV Vibe Container

This fork retains the original `sagetv-dockers` history and adds
`opensagetv-vibe-server`: a clean Linux/amd64 SageTV server on Ubuntu 26.04 and
OpenJDK 11. It supports Intel QSV, AMD VAAPI, and NVIDIA device integration,
uses an in-container restart supervisor, and has production and debug targets
from one Dockerfile.

The canonical interface is the sibling build-environment wrapper:
`opensagetv-vibe-dev.ps1 all` on Windows or `opensagetv-vibe-dev.sh all` on
Linux. It stages the locally tested Core, XMLTV, and Core MCP plugin outputs, builds
both targets, starts a clean server, performs lifecycle-soak, discovery,
plugin, and OpenDCT tests, and creates offline image exports. `build.sh` and
`build.ps1` remain component
developer conveniences; a release must use the unified pipeline.

## Distribution and commissioning

This project does not publish container images to GHCR, Docker Hub, or another
registry. The unified release pipeline writes checksummed production and debug
image archives under `output/releases/<version>/images/`. Transfer the selected
archive and its `.sha256` file to the target host, verify it, and load it:

```bash
sha256sum -c opensagetv-vibe-server-u26-gpu-j11.tar.gz.sha256
gzip -dc opensagetv-vibe-server-u26-gpu-j11.tar.gz | docker load
```

The `ghcr.io/...` image spelling is retained only as the canonical local tag
stored inside the archive and referenced by the Unraid XML. No workflow in this
repository logs into a registry or executes `docker push`.

The runtime image is a stable Ubuntu/Java/GPU environment. Ordinary Core,
XMLTV, TMDB, Comskip, or separately installed FFmpeg-plugin changes do **not**
require rebuilding that image.
Build and validate the component in `opensagetv-vibe-dev`, create a verified
component update, install it into appdata, and restart only SageTV. Use
`runtime-image-status` to see whether an OS/container input actually changed;
`runtime-images` exits successfully without rebuilding when the production and
debug fingerprints already match. Set `FORCE_RUNTIME_IMAGE_BUILD=true` only
for an intentional runtime-baseline refresh.

```bash
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh runtime-update-package core
./scripts/deploy-component-update.sh \
  output/component-updates/opensagetv-vibe-core-REVISION.tar.gz \
  UNRAID_HOST SSH_PRIVATE_KEY
```

The same update path supports `core`, `xmltv`, `tmdb`, and `comskip`. The FFmpeg
runtime is installed and updated through `opensagetv-vibe-SageTVFFmpegPlugin`,
not as a container component. The component path verifies
hashes, stops only the selected test container, backs up replaced files,
installs atomically under appdata, restarts the container, and runs a
component-specific health check. `rollback-component-update.sh` restores the
most recent backup. Never target the protected production container unless an
administrator explicitly chooses it.

For component-only takeover and updates, use the consistent root interface in
[`WORKFLOW.md`](WORKFLOW.md). Every launcher resolves from its own directory.

The artifact staging script rejects missing files, an invalid Core gzip, an
invalid XMLTV JAR, or any source/destination hash
mismatch. Runtime images receive OCI and component revision labels for the exact
source commits used by the build.

Runtime validation reuses its one temporary SageTV container for an unexpected
JVM-exit recovery and three complete container restart cycles. Every cycle
requires TCP readiness, healthy Docker state, Tini as PID 1, zero zombies, a
live PID file, and bounded file-descriptor, thread, and RSS growth. Set
`OPENSAGETV_VIBE_RESTART_CYCLES` to a value of at least two to lengthen the
test; the unified Windows and Linux wrappers forward it into the development
container.

For Unraid, load the saved image on the low-power server and install
`unRAID/opensagetv-vibe/sagetv-vibe-server-u26-gpu-j11.xml` as a CA template. Assign a
unique custom `br0` IP so this clean instance can coexist with the current
server. Its container name is `sagetv-vibe-server-u26-gpu-j11` and its appdata
default is `/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11`; no
configuration is migrated.

The guarded `scripts/recreate-unraid-test-container.py` replacement helper
keeps the previous Vibe container only while the replacement passes Docker
health, expected-IP, and a default 30-second continuous stability gate. It
automatically restores the previous container if that gate fails. After the
gate succeeds, it removes the stopped prior container and its unreferenced
Vibe-owned image; it never prunes globally or targets another container.
`--retain-rollback` is available only for an intentional rollback
investigation.

The bundled XMLTV importer is registered automatically as
`xmltv.XMLTVImportPlugin`; SageTV's obsolete EPG license service is not used.
Reusable `common.properties` and `xmltv_*.profile` files are seeded directly in
the SageTV server root on first start. Existing user-modified profiles are not
overwritten on an image upgrade. Provider examples remain under
`.config/xmltv-examples`.

Every Vibe server image also includes and registers the bounded
`OpenSageTVVibeCoreMCPPlugin` Standard plugin. The plugin starts enabled but
securely listens only on `127.0.0.1:8270` and generates a unique bearer token.
An administrator must explicitly allow a LAN listener before an external MCP
adapter can connect. Image upgrades refresh the tested plugin JAR when its
seed fingerprint changes while preserving its enable state, listener choices,
and token in persistent appdata. The exact Core MCP seed also participates in
the image-reuse fingerprint, so a later plugin revision cannot silently retain
an older image.
The Unraid template maps `/mnt/user` to `/unraid` so provider files such as
`/unraid/appdata/xmltvdata/*.xml` remain readable. A clean install creates
`Sage.properties` before applying these container-managed defaults.

For HTTPS feeds or channel-logo sites intercepted by a private TLS gateway,
place the administrator-provided root CA (`.crt`, `.cer`, or `.pem`) under
`/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11/certs`. At each startup the
container validates those files and imports them into Java's trust store.
Certificate checking remains enabled; the image never uses a trust-all TLS
handler.

The image includes Ubuntu 26's `libvpl2`, `libmfx-gen1.2`, Intel media driver,
Mesa VAAPI/Vulkan runtime packages, and Ubuntu's supported FFmpeg runtime.
The SageTV `ffmpeg` executable therefore has a complete matching Ubuntu 26
runtime instead of depending on libraries omitted from a minimal image.
`libmfx-gen1.2` supplies the Intel GPU implementation required when an external
FFmpeg plugin selects QSV; `libvpl2` alone is only the dispatcher. The image
does not bundle, seed, enable, reset, or update Vibe FFmpeg/MIM. Without the
optional plugin SageTV uses its stock `ffmpeg`; with the plugin installed, the
plugin performs capability preflight and deterministic software fallback.

## Persistent appdata payload policy

On a clean deployment the image seeds Core, stock `ffmpeg`/`ffmpeg.stock`,
XMLTV, Core MCP, Comskip, and container-owned plugin assets into appdata. Appdata is then authoritative:
manual or component-package replacements survive SageTV and Docker restarts.
On an actual image update, only payloads whose image seed fingerprint changed
are refreshed. Database, properties, plugin state, XMLTV profiles, recordings,
and unrelated administrator files are never reset. The explicit
`*_RESET_FROM_IMAGE=true` options remain recovery controls, not normal update
steps.
