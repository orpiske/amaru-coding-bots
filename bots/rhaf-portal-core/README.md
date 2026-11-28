# RHAF Portal Core coding bot

Amaru Light uses Codex to work on issues labelled `needs-implementation` in
`rhaf-ai/rhaf-portal-core`. It pushes branches to `orp-bot/rhaf-portal-core`
and opens pull requests against `main`. Install the agent on the Agents page.

The image pins Rust 1.96.0 with Clippy and rustfmt to match the project's
`rust-toolchain.toml` and `.github/workflows/pr-build.yml`. The agent CLIs
come from the Agents page. The bot runs the PR workflow's workspace lint
inheritance, formatting, Clippy, build, test, and OpenAPI snapshot checks.

GitHub Actions runs the container build and smoke test, which require a
container runtime. It also runs the Portal integration suite, which uses
Java 21, Maven, and a fixture built from the separate `rhaf-ai/rhaf-portal-tests`
checkout. Those tools and fixtures are outside this image.

Before running the bot, create the fork and the intake label upstream, and
supply the bot account's token in `GH_TOKEN`. Give the bot upstream access
if you want to use assignee-based intake. See [Running a bot](../../docs/running-a-bot.md).

## Build cache

The image ships [kache](https://github.com/kunobi-ninja/kache) 2.4.0, and
`RUSTC_WRAPPER` sends every rustc call through it, so a new worktree reuses
the crates an earlier ticket compiled. The cache lives in `~/.cache/kache`
on the home volume and survives a new image; its daemon starts with the
first compile. Run `podman exec <container> kache stats` to see the hit
rate. Set `KACHE_DISABLED=1` (with `-e`) to turn it off, or `KACHE_MAX_SIZE`
to change its disk budget (by default 5% of the disk, at least 5 GiB).
