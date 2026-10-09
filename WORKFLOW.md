# Common project workflow

## Task fix and server-boundary policy

Apply this policy to every task workflow, including dependency fixes across
Vibe repositories. Fix and test necessary plugins and update the test-server
plugin without asking again solely for repository-boundary approval.

Prefer the Android client, then a stock-compatible plugin. Change non-stock
`.232` Core only for a proven production defect that neither can correct;
document the API gap and alternatives, keep optional negotiation and safe
stock/older-client fallback, and run affected compatibility tests. Never patch
Core merely to simplify testing.

Stock `.175` installation changes are limited to plugin installation/update.
Do not modify its stock Sage.jar, stock FFmpeg, Core binaries, or server
installation/configuration files. Preserve user settings, recordings and
unrelated clients; reversible supported SageTV playback APIs remain allowed.

Non-stock `.232` restarts are authorized for task updates without asking
again; coordinate them with active test guards and preserve data/settings.
  Always ask the user before restarting stock `.175`, even when it appears idle,
  unless an explicit user-granted bounded restart window is active. Record
  its UTC expiry in the task/handoff, and check expiry and revocation before
  every restart. After expiry or revocation, ask again; stock files stay protected.

Update owning TASKS.md, linked dependencies and the workspace suggested order
as work changes; move completed checkoffs into the checklist change ledger.
Test only affected gates, preserve unrelated completed matrices, and do not
stop independent authorized work for a status question or a dependency-only
permission request. Unrelated work, publication, destructive actions and
interruption of recordings/other users still require their own authority.

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

When commissioning a newly loaded runtime image,
`scripts/recreate-unraid-test-container.py` preserves the previous Vibe test
container only until the replacement passes health, expected-IP, and stability
verification. Successful verification removes the old stopped container and
its unreferenced Vibe image automatically. Use `--retain-rollback` only when an
explicit diagnostic rollback gate requires it. The protected production
container and unrelated Unraid resources remain outside this workflow.
