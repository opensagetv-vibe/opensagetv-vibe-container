# Container handoff

The container repository is now integrated into the one reusable
`opensagetv-vibe-dev` workflow. `stage-artifacts.sh` validates and stages the
exact Core, Linux MIM, and XMLTV outputs; `build.sh` labels production/debug
images with all component commits; `tests/runtime-validation.sh` creates a
clean appdata volume, verifies SageTV health, one supervisor-controlled JVM
recovery, three full restart cycles, zero zombies, bounded lifecycle metrics,
UDP discovery, TCP service, XMLTV selection, OpenDCT protocol behavior, and
then proves its temporary container, network, anonymous volumes, and named
volume were removed.

The repository's `.gitattributes` must keep both `*.sh` files and the
extensionless scripts under `modern/rootfs/usr/local/bin` on LF line endings.
This is part of runtime correctness: Windows Git clients otherwise preserve LF
in the index but materialize CRLF shebangs in a fresh worktree.

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

MIM 0.4.5 is deliberately false by default. Hardware decode defaults true,
but actual acceleration requires the matching host device/runtime. The image
installs both `libvpl2` and `libmfx-gen1.2`; the latter is required for the
Intel media driver to create the QSV session. Clean-image tests assert that the
package is present. The optional license field is retained for plugin
compatibility and is not required by SageTV.

The 2026-08-26 production and debug images were rebuilt from the unified
outputs. The embedded Linux MIM SHA-256 matched the tested artifact exactly,
both images reported MIM 0.4.5, the debug image contained `gdb`, and the
production clean-appdata regression passed. Do not enable MIM until Android
MiniClient and physical AMD/NVIDIA commissioning are complete.

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
