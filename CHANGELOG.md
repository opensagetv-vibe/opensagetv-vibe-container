# Change Log

## Next

- Bundled the stock-compatible OpenSageTV Vibe Core MCP Standard plugin in
  every production and debug image. Clean and upgraded appdata receive the
  tested JAR and plugin registration automatically, while the secure
  loopback-only listener, generated bearer token, and administrator settings
  remain persistent. Runtime validation now proves plugin startup and health.
- Included the required Core MCP seed in the runtime-image fingerprint and
  staged it before direct-build reuse decisions, preventing a plugin-only
  revision from incorrectly retaining an older image.

- Removed Vibe FFmpeg/MIM binaries, INI seeding, enable/reset variables, image
  labels, and container component updates from the server image. Stock SageTV
  `ffmpeg` remains the no-plugin fallback; GPU/system runtimes remain available
  for the separately installed OpenSageTV Vibe FFmpeg Plugin, which owns its
  bridge, runtime, configuration, upgrades, and software fallback.

- Updated repository CI to the current Node 24-based
  `actions/checkout@v7` release. The credential scan excludes its own workflow
  source so the forbidden-pattern expression cannot trigger a false positive.
  The workflow runner is pinned to Ubuntu 24.04 for reproducibility.
  Maintained Linux workflow/component/test entry points now carry executable
  Git metadata, with CI checks preventing regressions.
- Added TMDB as a component-only appdata update. Packages install the service,
  pinned dependency JARs, metadata, and credential-free example atomically,
  preserve administrator-owned `tmdb_config.toml`, and support verified
  rollback without rebuilding Docker.

- Defined source-and-file-only distribution: releases export checksummed Docker
  archives for `docker load` commissioning and never publish images to a
  registry. Historical upstream push helpers now fail closed.
- Added repository checks, contribution/security guidance, and licensing
  provenance for public OpenSageTV Vibe development.

- Added verified Core, MIM, XMLTV, and Comskip component-update archives with
  atomic appdata installation, automatic backup/rollback, installed-revision
  metadata, targeted container restart, and component-specific health checks.
  The complete package/install/rollback self-test passes for all four payloads,
  and MIM 0.4.7 was commissioned on the isolated Unraid test server without
  restarting the protected production SageTV or OpenDCT containers.
- Changed runtime payload ownership so a clean deployment seeds appdata once,
  administrator/component updates persist across restarts, and an image update
  refreshes only payloads whose image seed fingerprint changed. Core keeps its
  stock FFmpeg as `ffmpeg.stock`; MIM and other appdata binaries can be replaced
  without rebuilding the Docker image.
- Added a runtime-environment fingerprint and `runtime-image-status`. Matching
  production/debug images are reused immediately; an explicit
  `FORCE_RUNTIME_IMAGE_BUILD=true` is required for a deliberate identical-
  environment refresh.
- Switched runtime construction to Docker Buildx/BuildKit and added
  project-scoped cleanup of obsolete Vibe layers. Validation leaves one
  production image, one debug image, zero dangling project images, and never
  globally prunes unrelated Docker resources.

- Refreshed the staged Linux FFmpeg/MIM payload from the unified 0.4.6 output
  after commissioning found a mixed image context: `ffmpeg` was 0.4.6 while
  `ffmpeg_MIM` and `ffmpeg.real` were older. `stage-artifacts.sh` now passes
  with wrapper SHA-256
  `668c056eb05c77e2ad3303ac1b351103f7367a93a44904e7b430b971da724f80`
  and runtime SHA-256
  `fc36882f4c0bfd94910f15cc285c0daf29b31b11598bc3e2df9f089fb3578519`.
- Rebuilt the production/debug images with the Core STV-caption protocol and
  commissioned production tag `sagetv-vibe-server-u26-gpu-j11:caption-state`
  on the isolated Unraid test instance. The running and appdata `Sage.jar`
  hashes both equal
  `10778d299874bbcfbc741d16fa4b464e670b598f0b08af88457aef0441daf15c`;
  server health and STV-authoritative Media3/legacy-Exo captions passed.
- Added Ubuntu 26's supported `ffmpeg` package to the production/debug runtime
  so the Core `ffmpeg` launcher always has its matching modern shared-library
  set. Runtime validation executes both the Core FFmpeg and optional MIM
  binaries and rejects missing dependencies.
- Extended `VIBE_TEST_CONTROL` to feature-gate both exact indexed-file event
  230 and exact dotted-channel event 231. The default remains false.
- Added a guarded Unraid test-container replacement helper. It preserves the
  existing configuration and IP, retains a stopped timestamped rollback
  container, and automatically restores it if the replacement fails health.
- Built and commissioned the exact final export on the isolated Unraid test
  instance at `192.168.10.232`. Image config ID is
  `sha256:fb6ebf551d9cc3fbf1ccfd1dffc6ef52aa1270f3edfbdbe9c5be90ad755858c0`;
  pinned and appdata `Sage.jar` both hash to
  `0a8755fbbd66a4fd96a28fa8d462d3369d58d7769032ffc9d330ee36b365f889`.
  Media3, legacy ExoPlayer, and a last/bounded GSY System run each produced
  advancing live audio/video and completed exact 5.1/2.1 transitions without
  a client or server crash. MIM remained disabled.
- Synchronize the pinned executable distribution into existing appdata on
  every startup while preserving `Wiz.bin`, `Wiz.bak`, `SageTVPlugins.xml`,
  and `filetracker.properties`. Runtime validation seeds a stale `Sage.jar`
  and fails unless the exact pinned image artifact replaces it.
- Added advanced `VIBE_TEST_CONTROL`, default false, which maps to the Core
  exact-path MiniClient property for commissioned hardware tests. The final
  image was loaded on Unraid at `192.168.10.232`; pinned/appdata JAR hashes
  matched and exact-path full-screen MPEG-2/AC-3 playback passed.
- Made clean-appdata runtime validation wait for the actual first-run
  `Sage.properties` contract instead of racing the JVM process healthcheck.
  This keeps a fast Java start from producing a false missing-properties
  failure.
- Added the shared AI takeover, task, verified changed-files update, resumable
  test/validate/build/install, and handoff ZIP interface.

* Enforced LF checkout for extensionless modern runtime entrypoint,
  supervisor, option, and GPU helper scripts. This prevents Windows fresh
  clones from producing an image that exits with `env: bash\r: No such file or
  directory`.
* Added a configurable runtime restart soak using the existing temporary test
  container: one intentional Sage JVM exit exercises the in-container
  supervisor, followed by three complete Docker restart cycles. Each cycle
  validates TCP readiness, health, Tini PID 1, the Java PID file, zero zombies,
  supervisor progress, and bounded descriptor/thread/RSS growth.
* Moved source-revision build arguments and OCI labels below the expensive
  Ubuntu runtime package and artifact layers. A commit/label-only rebuild no
  longer forces `apt` and GPU runtime packages to be downloaded again.
* Integrated runtime image construction and validation into the unified
  build-environment `all` command.
* Added exact-hash staging for Core, Linux FFmpeg/MIM, and XMLTV artifacts.
* Added OCI source/component revision labels and targeted cleanup of superseded
  project image IDs after a successful rebuild.
* Added a clean runtime validation harness covering production/debug metadata,
  clean appdata, Java health, independent-peer UDP discovery, TCP 42024, XMLTV
  no-license auto-selection, OpenDCT V3 wire behavior, and labeled Docker
  container/network/volume cleanup.
* Added an optional real OpenDCT scan gate that reports `SKIPPED` unless a
  commissioned host, port, and encoder are explicitly supplied.
* Standardized the Unraid container identity as `sagetv-vibe-server-u26-gpu-j11` and its clean appdata path as `/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11`.
* Renamed the commissioned Unraid instance in place without rebuilding it, verified health at `192.168.10.232`, and removed only its stopped backup containers and obsolete project image revisions. The production `sagetvopen-sagetv-server-java11` instance was not changed.
* Renamed the project, runtime images, Unraid CA template, clean appdata
  default, test container, and sibling repository paths to the full
  `opensagetv-vibe-*` namespace.
* Added Ubuntu 26 `libmfx-gen1.2` to production and debug images so Intel QSV can create a real oneVPL/media-driver session instead of merely detecting the encoder name.
* Added a clean-container assertion for the Intel QSV runtime implementation.
* Staged and verified MIM 0.4.5 from the unified build output; the embedded binary SHA-256 exactly matches the tested Linux artifact and remains disabled by default.
* Seed XMLTV `common.properties` and reusable `xmltv_*.profile` files in the SageTV server root without overwriting user-customized copies.
* Validate presence of common, EPG123, and Pluto profiles in the clean-container regression test.
* Fixed the PowerShell clean-install regression harness to remove its anonymous runtime volumes along with the temporary container, preventing five leaked Docker volumes per test run.
* Added persistent, administrator-controlled Java CA certificate import from `/opt/sagetv/certs` for XMLTV/logo HTTPS endpoints behind private TLS gateways; TLS verification remains enabled.
* Embedded XMLTV channel-logo downloading now honors both historical and current enable keys and produces bounded, normalized PNG files.
* Initialize an empty `Sage.properties` on a clean appdata volume before applying container-managed discovery and XMLTV provider defaults. SageTV can then populate its normal defaults without requiring historical appdata.
* Register the installed XMLTV importer in `epg/epg_import_plugin` on every startup so SageTV does not route XMLTV setup through the retired license-key flow.
* Added container regressions for clean startup, XMLTV JAR/property installation, Core discovery with a missing property, and Core fallback from an invalid legacy importer class.
* Restored the `/mnt/user` to `/unraid` Unraid share mapping used by existing XMLTV configuration paths.
* Added the OpenDCT 0.5.32 V3 `AUTOINFOSCAN` token-count fix and a wire-level regression test. This prevents a scan from reusing the GenericPipe `TEST01` device and restores HDHomeRun channel results.
* MiniClient discovery now records the current container IPv4 address on every startup when `MINI_DISCOVERY_BIND_ADDRESS=auto`.
* Startup rejects an explicitly configured discovery address that is not assigned to the container, preventing silent failure after switching between host and br0 networking.
* Verified SageTV UDP discovery from an independent Unraid br0 peer: the server at `192.168.10.232:31100` returned the expected 15-byte `STV` response.
* The Unraid deployment remains a separate clean instance using
  `/mnt/user/appdata/sagetv-vibe-server-u26-gpu-j11`; no existing SageTV settings are
  included.
