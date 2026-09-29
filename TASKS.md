# OpenSageTV Vibe Container tasks

This is the only active container backlog. Completed work is removed and
recorded in `CHANGELOG.md` and `HANDOFF.md`.

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
