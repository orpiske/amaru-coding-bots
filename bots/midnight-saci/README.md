# Midnight Saci coding bot

The coding bot for [orpiske/midnight-saci](https://github.com/orpiske/midnight-saci).
`orp-bot` picks issues labelled `needs-implementation`, works on them with
Codex and opens pull requests from its fork `orp-bot/midnight-saci`. It
never merges.

- Repository: `orpiske/midnight-saci` (fork `orp-bot/midnight-saci`,
  branches `feat/...`)
- Agent: Codex (install it on the Agents page; Claude Code and IBM Bob are
  defined too, set `agent: claude` or `agent: bob` in `project.yaml` to
  switch)
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

## Build cache

The image ships [kache](https://github.com/kunobi-ninja/kache) 2.4.0, and
`RUSTC_WRAPPER` sends every rustc call through it, so a new worktree reuses
the crates an earlier ticket compiled. The cache lives in `~/.cache/kache`
on the home volume and survives a new image; its daemon starts with the
first compile. Run `podman exec <container> kache stats` to see the hit
rate. Set `KACHE_DISABLED=1` (with `-e`) to turn it off, or `KACHE_MAX_SIZE`
to change its disk budget (by default 5% of the disk, at least 5 GiB).
