# RHAF Portal Core coding bot

Amaru Light uses Codex to work on issues labelled `needs-implementation` in
`rhaf-ai/rhaf-portal-core`. It pushes branches to `orp-bot/rhaf-portal-core`
and opens pull requests against `main`. The image also includes Claude Code.

The image pins Rust 1.96.0 with Clippy and rustfmt to match the project's
`rust-toolchain.toml` and `.github/workflows/pr-build.yml`. It uses Node.js
22 for the agent CLIs. The bot runs the PR workflow's workspace lint
inheritance, formatting, Clippy, build, test, and OpenAPI snapshot checks.

GitHub Actions runs the container build and smoke test, which require a
container runtime. It also runs the Portal integration suite, which uses
Java 21, Maven, and a fixture built from the separate `rhaf-ai/rhaf-portal-tests`
checkout. Those tools and fixtures are outside this image.

Before running the bot, create the fork and the intake label upstream, and
supply the bot account's token in `GH_TOKEN`. Give the bot upstream access
if you want to use assignee-based intake. See [Running a bot](../../docs/running-a-bot.md).
