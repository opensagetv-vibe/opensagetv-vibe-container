# OpenSageTV Vibe Container tasks

> **Pre-commit task maintenance:** Immediately before every repository commit, move
> completed `[x]` items out of active sections and into
> `## Checklist change ledger`. Preserve IDs, evidence, and context; never
> discard completion history. Active sections contain unchecked work only.

This is the only active container backlog. Completed work moves to the
checklist change ledger; release evidence is also recorded in `CHANGELOG.md`
and `HANDOFF.md`.


- [ ] TOP PRIORITY: validate one current-Ubuntu runtime design with both a
  canonical stock SageTV Core payload and the Vibe Core payload. Prove clean
  non-root startup, PID/supervisor behavior, Java 11, UDP/TCP services,
  stock-FFmpeg fallback, optional FFmpeg-plugin installation, and access to
  current Intel/AMD/NVIDIA userspace driver stacks without making the stock
  server depend on Vibe-only Core behavior. Prepare the smallest reviewable
  container PR for `OpenSageTV/sagetv-dockers` only after its required
  `google/sagetv` Core PRs and stock-runtime evidence are documented.
- [ ] Test Intel QSV, AMD VAAPI, and NVIDIA paths on real hardware, including
  deterministic software fallback after hardware initialization failure.

## Checklist change ledger

- [x] **PLUGIN-RENAME-001 (2026-10-21):** XMLTV source paths use canonical
  Xmltv-Plugin casing; FFmpeg documentation links use FFmpeg-Plugin. Six host
  source/helper tests pass; runtime JAR/plugin IDs, images and settings unchanged.
  No server restart or hardware retest required for source-path metadata.

- [x] **XMLTV-PLUGIN-002 source dependency (2026-10-18).** Update five
  default sibling source/output paths for build/stage/update/runtime checks
  to opensagetv-vibe-xmltv-Plugin. Established JAR/component/image labels and
  runtime bootstrap stay unchanged; syntax/source-path contracts pass. No
  image rebuild/replacement, appdata mutation or physical runtime claim.

- 2026-10-08 pre-commit source-sync review: workflow policy only, no runtime
  image replacement or server restart. Four guarded-cleanup unit contracts and
  common workflow checks pass; existing hardware/runtime tasks remain open.
  Completed items are ledger-only; workspace execution order reviewed305.
