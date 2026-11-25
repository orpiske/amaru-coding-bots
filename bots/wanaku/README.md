# Wanaku coding bot

The coding bot for [wanaku-ai/wanaku](https://github.com/wanaku-ai/wanaku).
`orp-bot` picks issues labelled `needs-implementation`, works on them with
Codex and opens pull requests from its fork `orp-bot/wanaku`. It never
merges.

- Repository: `wanaku-ai/wanaku` (fork `orp-bot/wanaku`, branches `amaru/...`)
- Agent: Codex
- Checks: `pr-rust` (the wasm actions with cargo-component, build, tests,
  the OpenAPI snapshot, clippy; 60m) and `pr-ui` (yarn format check and
  tests in `ui/admin`; 15m), as Wanaku's PR build runs them
- Web interface: port 8766
- Toolchain: Rust 1.96 with the `wasm32-wasip1` target, cargo-component
  0.21.1, Node.js 22, Yarn 1.22.22. Keep these in step with Wanaku CI.

`CARGO_BUILD_JOBS=2` and no debug info keep the build within a small
Podman VM. Raise the jobs on a bigger host.

To run it, see [Running a bot](../../docs/running-a-bot.md). Wanaku's own
account setup notes are in its `docs/contributing/coding-bot.md`.
