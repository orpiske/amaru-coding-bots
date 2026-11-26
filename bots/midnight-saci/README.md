# Midnight Saci coding bot

The coding bot for [orpiske/midnight-saci](https://github.com/orpiske/midnight-saci).
`orp-bot` picks issues labelled `needs-implementation`, works on them with
Codex and opens pull requests from its fork `orp-bot/midnight-saci`. It
never merges.

- Repository: `orpiske/midnight-saci` (fork `orp-bot/midnight-saci`,
  branches `feat/...`)
- Agent: Codex (Claude Code is installed too; set `agent: claude` in
  `project.yaml` to switch)
- Checks:
  - `check`: `.github/check-docs.sh && make check` (docs conventions,
    `cargo fmt --check`, clippy with `-D warnings`, `cargo test`; 30m);
  - `web`: `npm ci`, `npm run check` (API types, type check, unit tests)
    and `npm run build` in `web/`, then the backend's `console` test
    (20m).
- Web interface: port 8765 in the container (publish it on any host port)
- Toolchain: Rust 1.97.1 with clippy and rustfmt (from
  `rust-toolchain.toml`), Node.js 22 (as CI), gcc, g++ and cmake for the
  native crates. Keep the Rust pin in step with `rust-toolchain.toml`.

What the image cannot run, so it is left to Midnight Saci CI:

- the browser and accessibility tests (`npm run e2e`): no browser;
- `make image-check`, the worker image jobs and the Kubernetes job: no
  container runtime or cluster;
- markdownlint and the lychee link check.

To run it, see [Running a bot](../../docs/running-a-bot.md).
