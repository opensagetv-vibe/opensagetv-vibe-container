# OpenSageTV Vibe Container contributor rules

Read `README.md`, `HANDOFF.md`, `TASKS.md`, and `WORKFLOW.md` first. Use only
the unified development image/container. `TASKS.md` is the sole local backlog;
remove completed items and update `CHANGELOG.md`/`HANDOFF.md` immediately.

Never migrate or package user appdata, `Sage.properties`, `Wiz.bin`, recordings,
credentials, or license data. Preserve clean-install defaults, external
FFmpeg-plugin ownership, software hardware fallback, Tini/supervisor behavior,
Unraid coexistence, and
temporary-resource cleanup. Do not create per-version/prompt/review documents.


## Stock-server test-control policy

- For any new testing, commissioning, diagnostic, or automation control, first
  implement or extend the stock-compatible `opensagetv-vibe-core-MCP-Plugin`
  using supported `sage.SageTV.api`/`apiUI` calls and verify it against an
  unmodified stock SageTV server.
- Do not patch `Sage.jar`, add private MiniClient events, or change Core merely
  to make a test easier. Existing public APIs, the bounded MCP bridge, and
  external test tooling are the required first option.
- Change Core only when the required production runtime behavior cannot be
  expressed through the stock plugin/API boundary. Document the proven API
  gap, keep the extension optional and negotiated with a safe stock fallback,
  and verify older clients and installations remain unaffected.
