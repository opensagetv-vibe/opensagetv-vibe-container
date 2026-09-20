# Contributing

Read `AGENTS.md`, `README.md`, `WORKFLOW.md`, and `TASKS.md` before changing the
container. Use the sibling `opensagetv-vibe-build-env` checkout and run:

```bash
./dev.sh test
./dev.sh validate
./dev.sh build
./dev.sh install
```

Keep FFmpeg/MIM owned by the separately installed FFmpeg plugin, preserve
stock-FFmpeg clean-install behavior and appdata, and
never add a registry login/push step. Update `CHANGELOG.md`, `HANDOFF.md`, and
`TASKS.md` in the same change.
