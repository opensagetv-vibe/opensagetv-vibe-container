# Common project workflow

Run `dev.cmd` or `./dev.sh` with `test`, `validate`, `build`, `install`, or
`all`. Test checks scripts, validate stages exact component artifacts, build
creates production/debug images, and install runs clean runtime validation; it
does not deploy to or modify Unraid.

Put changed-files ZIPs in `artifacts/downloads`, then run `update.cmd` or
`./update.sh`. Generate a verified package with `create_ai_handoff_zip.cmd`.
The sibling build environment's `WORKFLOW.md` defines the shared format.

## Fast runtime component updates

Use the one unified development container to build the changed component, then
package only that payload:

```bash
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh runtime-update-package core
../opensagetv-vibe-build-env/opensagetv-vibe-dev.sh runtime-update-test core
```

Valid names are `core`, `xmltv`, `tmdb`, and `comskip`; `runtime-update-test
all` runs the package/install/rollback self-test for every component. Updates
are written under `output/component-updates` with a SHA-256 sidecar.

FFmpeg/MIM is intentionally not a container component. Build its runtime in
`opensagetv-vibe-ffmpeg-mim` and install/update it through
`opensagetv-vibe-SageTVFFmpegPlugin`. The plugin owns `SageTVTranscoder` and
`plugins/SageTVFFmpegPlugin/runtime`; the container retains stock `ffmpeg` as
the no-plugin and failure fallback.

Deploy a tested package to the isolated Unraid instance without rebuilding or
reloading Docker:

```bash
./scripts/deploy-component-update.sh UPDATE.tar.gz 192.168.10.175 SSH_KEY
```

The default target is container `sagetv-vibe-server-u26-gpu-j11` and appdata
`/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11`. Override them only with
the explicit `SAGETV_CONTAINER` and `SAGETV_APPDATA` variables. The installer
creates an appdata backup before replacement and fails/rolls back on an
unhealthy restart. Use `scripts/component-status.sh` for installed revision
and hash evidence and `scripts/rollback-component-update.sh` for recovery.

## Runtime image rebuild policy

Run `runtime-image-status` first. Rebuild production/debug images only when
Ubuntu packages, Java, drivers, system libraries, the runtime Dockerfile,
entrypoint/supervisor, or other container-environment inputs change. Core,
XMLTV, TMDB, and Comskip source edits use component updates. FFmpeg/MIM uses
the separate SageTV plugin lifecycle. `build.sh` uses
BuildKit cache, skips matching fingerprints, and removes only obsolete
OpenSageTV Vibe image layers; it never performs a global Docker prune.
