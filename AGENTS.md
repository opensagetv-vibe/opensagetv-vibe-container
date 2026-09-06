# OpenSageTV Vibe Container contributor rules

Read `README.md`, `HANDOFF.md`, `TASKS.md`, and `WORKFLOW.md` first. Use only
the unified development image/container. `TASKS.md` is the sole local backlog;
remove completed items and update `CHANGELOG.md`/`HANDOFF.md` immediately.

Never migrate or package user appdata, `Sage.properties`, `Wiz.bin`, recordings,
credentials, or license data. Preserve clean-install defaults, MIM disabled by
default, hardware fallback, Tini/supervisor behavior, Unraid coexistence, and
temporary-resource cleanup. Do not create per-version/prompt/review documents.
