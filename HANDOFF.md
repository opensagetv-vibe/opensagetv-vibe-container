# Container handoff

## Publication policy

Publish this repository's source and the unified pipeline's checksummed
commissioning files only. Do not push the production or debug image to a
container registry. The image tag embedded in the offline archive matches the
Unraid XML so a verified `docker load` is sufficient before commissioning.

## Standard takeover

Read `AGENTS.md`, `README.md`, `TASKS.md`, and `WORKFLOW.md`. The common root
workflow maps install to clean runtime validation, never to an automatic Unraid
deployment. Changed-files packages live in `artifacts/downloads`.

The container repository is now integrated into the one reusable
`opensagetv-vibe-dev` workflow. `stage-artifacts.sh` validates and stages the
exact Core and XMLTV outputs; `build.sh` labels production/debug
images with all component commits; `tests/runtime-validation.sh` creates a
clean appdata volume, verifies SageTV health, one supervisor-controlled JVM
recovery, three full restart cycles, zero zombies, bounded lifecycle metrics,
UDP discovery, TCP service, XMLTV selection, OpenDCT protocol behavior, and
then proves its temporary container, network, anonymous volumes, and named
volume were removed.

As of 2026-09-20, the container no longer bundles or seeds Vibe FFmpeg/MIM.
It retains stock SageTV `ffmpeg` and optional GPU/system driver libraries.
`opensagetv-vibe-SageTVFFmpegPlugin` exclusively owns the root
`SageTVTranscoder` bridge and `plugins/SageTVFFmpegPlugin/runtime`. A missing,
disabled, partially removed, or hardware-incompatible plugin falls back to
stock FFmpeg or the plugin runtime's deterministic software path. Historical
MIM component-update notes below describe the superseded pre-plugin design.

On 2026-08-30 the runtime workflow moved to Buildx/BuildKit plus an explicit
environment fingerprint. The canonical production/debug image IDs are
`sha256:89af7475dec66aef328113f9de3b33bf24a656e8b4b6de44153429e4e0d1613a`
and
`sha256:89d55c387a27cacf67c3021c11123cd97b16a897fd2153a9063f3d83c064f127`;
both carry fingerprint
`ffc4bbb4b0e3068245e1dc4abb25441e7be1e0b819510a26b9c278a49c8dfcfd`.
A second `runtime-images` call correctly skipped, and project-scoped cleanup
left zero dangling Vibe images without touching unrelated Docker resources.

Core, XMLTV, and Comskip application updates are independent of the
runtime image. `create-component-update.sh` produces a hashed package;
`install-component-update.sh` backs up and atomically replaces appdata files;
`deploy-component-update.sh` targets the isolated Unraid container; status,
health, and rollback helpers complete the lifecycle. FFmpeg/MIM uses the
separate SageTV plugin lifecycle. Rebuild Docker only for
Ubuntu/Java/driver/system-library or container-infrastructure changes.

TMDB now uses the same component-only path. Its targeted archive validation and
atomic install/rollback self-test pass, including exact JAR comparison and proof
that a pre-existing private `tmdb_config.toml` remains unchanged. The package
contains only the credential-free example. No runtime image rebuild is needed.

The repository's `.gitattributes` must keep both `*.sh` files and the
extensionless scripts under `modern/rootfs/usr/local/bin` on LF line endings.
This is part of runtime correctness: Windows Git clients otherwise preserve LF
in the index but materialize CRLF shebangs in a fresh worktree.

On 2026-08-29 the unified `runtime-all` pipeline rebuilt both image variants
from the clean Core archive, added Ubuntu FFmpeg to satisfy the complete modern
runtime dependency set, and passed clean startup, discovery, XMLTV,
OpenDCT-wire, supervisor recovery, three container restarts, and zero-zombie
validation. The exported production archive SHA-256 is
`144d152d08180496177b4d6b27da9bcffbe3c43e35889d5f0459710ce2cd9887`.
Docker Desktop reported local image-store ID
`sha256:98aa13d5f93b9aa3110a6e33f09058d8cc0cbbffc2554fb89ef14d85d3354ea5`;
the portable archive loaded on Unraid as config ID
`sha256:fb6ebf551d9cc3fbf1ccfd1dffc6ef52aa1270f3edfbdbe9c5be90ad755858c0`.
Both identities are recorded explicitly in release provenance.

A later caption-authority rebuild was loaded as
`sagetv-vibe-server-u26-gpu-j11:caption-state` and replaced only the isolated
test instance. Its runtime and appdata `Sage.jar` SHA-256 is
`10778d299874bbcfbc741d16fa4b464e670b598f0b08af88457aef0441daf15c`.
The retained rollback container is
`sagetv-vibe-server-u26-gpu-j11-rollback-20260829-125101`. The server stayed
healthy and both Android Exo backends rendered captions from the STV state;
production `sagetvopen-sagetv-server-java11` was not touched.

That exact export replaced only the isolated
`sagetv-vibe-server-u26-gpu-j11` instance while retaining the previous
container as `sagetv-vibe-server-u26-gpu-j11-rollback-20260829-085652`.
The replacement is healthy at `192.168.10.232`; pinned/appdata `Sage.jar`
hashes are both
`0a8755fbbd66a4fd96a28fa8d462d3369d58d7769032ffc9d330ee36b365f889`,
the Core launcher reports Ubuntu FFmpeg 8.0.1, and both exact-file and
exact-channel Vibe controls are true on this test instance. Media3 and legacy
ExoPlayer hardware Pull each passed fresh live playback plus 5.1/2.1 exact
transitions. GSY System was deliberately run last and bounded to two
transitions; it also produced advancing A/V and did not crash the Fire TV.
The protected production SageTV container was not touched.

On 2026-08-28 the freshly staged FFmpeg/MIM payload produced both production
and debug images. Clean-appdata runtime validation passed UDP discovery, TCP
service, XMLTV auto-selection, OpenDCT protocol simulation, supervisor-child
recovery, three Docker restarts, and zero-zombie checks. The physical
OpenDCT/HDHomeRun scan remained correctly `SKIPPED` because no commissioned
endpoint was configured for the local Docker Desktop run.

On 2026-08-29 production/debug images were rebuilt after adding executable
payload synchronization for existing appdata. Validation seeded a stale
`Sage.jar`, preserved database/plugin state, passed discovery/XMLTV/OpenDCT
and three restart cycles, and removed its temporary runtime resources. The
exact production image was loaded as
`sagetv-vibe-server-u26-gpu-j11:local` on Unraid. Its pinned and appdata
`Sage.jar` SHA-256 is
`9c8a72652dd09081a306dfd80be44aa7d3ab1b161ed4e3424c3377f1613b814f`.
The real Android exact-path test entered a 1920x1080 full-screen surface and
proved advancing MPEG-2 video and AC-3 audio. `VIBE_TEST_CONTROL=true` is for
this isolated test server only and defaults false in the image/template.

On 2026-08-27 those tests passed from Windows Docker Desktop through the
unified Ubuntu 26/Java 11 development container. A physical OpenDCT scan remains
an explicit target-network gate and was recorded as `SKIPPED`, not passed, when
no commissioned endpoint was supplied.

The restart soak records JVM PID, open file descriptors, threads, RSS, zombie
count, and cumulative supervisor starts after each recovery. Its default is
three Docker restart cycles plus one intentional child exit. The host wrappers
forward `OPENSAGETV_VIBE_RESTART_CYCLES` and the advanced timeout/growth-limit
variables defined in `tests/runtime-restart-soak.sh`.

XMLTV 3.5 profile assets are packaged with the plugin. On first start,
`common.properties` and every `xmltv_*.profile` file are copied to the SageTV
server root only when missing. This location is required by the importer and
keeps user-modified profiles persistent across image upgrades; examples remain
under `.config/xmltv-examples`.

The modern image is built only from the pinned Core archive placed in `artifacts/`; it never downloads `latest` at startup. Both production and debug targets use the same Ubuntu 26.04/OpenJDK 11 Dockerfile. The debug target adds diagnostic tools while preserving identical application bits and supervision.

The Unraid CA template is
`unRAID/opensagetv-vibe/sagetv-vibe-server-u26-gpu-j11.xml`. Commission it as
`sagetv-vibe-server-u26-gpu-j11` with a
user-selected unused `br0` address and the clean appdata path
`/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11`. Never point it at the current
production appdata.

MIM 0.4.6 is deliberately false by default. Hardware decode defaults true,
but actual acceleration requires the matching host device/runtime. The image
installs both `libvpl2` and `libmfx-gen1.2`; the latter is required for the
Intel media driver to create the QSV session. Clean-image tests assert that the
package is present. The optional license field is retained for plugin
compatibility and is not required by SageTV.

The current build context is staged from unified MIM 0.4.6. Its wrapper
SHA-256 is
`668c056eb05c77e2ad3303ac1b351103f7367a93a44904e7b430b971da724f80`
and `ffmpeg.real` is
`fc36882f4c0bfd94910f15cc285c0daf29b31b11598bc3e2df9f089fb3578519`.
The isolated Unraid server was repaired in place and proved those hashes
persist across restart; Intel VAAPI Fixed is commissioned as opt-in. MIM stays
disabled by default while AMD/NVIDIA physical commissioning remains open.

XMLTV is installed and registered on every startup through
`XMLTV_IMPORT_PLUGIN=xmltv.XMLTVImportPlugin`. This prevents Core from falling
back to the retired licensed Warlock EPG provider. The CA template includes the
required `/mnt/user:/unraid` mapping for XMLTV source paths. On an empty appdata
directory the entrypoint creates an empty `Sage.properties`, then SageTV fills
in its normal defaults on first launch. No old server settings are copied.

Optional private CA roots belong in persistent `/opt/sagetv/certs` (`.crt`,
`.cer`, or `.pem`). The root entrypoint validates and imports them into Java's
CA store before dropping privileges. This is required when an XMLTV or logo
HTTPS endpoint is intercepted by an enterprise proxy whose CA is not part of
Ubuntu; do not replace it with a trust-all TLS implementation.

The 2026-08-26 Unraid commissioning imported the administrator-controlled
Zscaler roots from persistent appdata, loaded XMLTV plugin version 3.2, and
completed the real 107-channel guide import. All 107 logos were valid PNGs at
or below 256x256, the plugin logged zero download failures, and the SageTV
container at `192.168.10.232` remained healthy.

Runtime validation on 2026-08-25 used the production image on Unraid at
`192.168.10.232`: Docker health was healthy, the Sage JVM remained running, the
plugin property and JAR were present, and the configured
`/unraid/appdata/xmltvdata/xmltv_60177.xml` source was readable. The immediately
previous test containers and their obsolete image revisions were removed after
the active instance was renamed and verified healthy on 2026-08-26.

MiniClient discovery uses UDP 31100 and replies through the same wildcard socket that receives the request. Keep `MINI_DISCOVERY_BIND_ADDRESS=auto`; the launcher refreshes the diagnostic property with the container's current IPv4 address on every start and rejects stale explicit addresses. On 2026-08-25 this was tested from a second Unraid br0 container and returned a valid response from `192.168.10.232:31100`.

OpenDCT 0.5.32 requires the patch under `integrations/opendct-0.5.32/` for V3
`AUTOINFOSCAN`. The original Unraid JAR is retained beside the installed JAR as
`opendct-0.5.32.jar.pre-autoinfoscan-fix`. The included protocol regression test
returned real ATSC channel rows from `atsc_hdhomerun_10703705`; it must not be
considered passing if all replies are blank or `ERROR`.
