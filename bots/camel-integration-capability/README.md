# Camel Integration Capability coding bot

The bot works on issues labelled `needs-implementation` in
[wanaku-ai/camel-integration-capability](https://github.com/wanaku-ai/camel-integration-capability).
It uses Codex and opens pull requests against `main` from
`orp-bot/camel-integration-capability`. Review feedback comes from `orpiske`.

- **Check** runs `mvn -B install --file pom.xml` with a 30-minute timeout.
  This is the PR workflow's Maven command and runs the build, unit tests,
  and integration tests. The check resolves the released Wanaku SDK from
  Maven Central. Upstream CI also builds the SDK from source for branch
  compatibility.
- **Toolchain** uses Eclipse Temurin 21 as specified in
  `.github/workflows/pr-builds.yml` upstream, Maven 3.9.11 to meet the 3.9+
  requirement in `CONTRIBUTING.md`, and Node.js 22 for Codex and Claude Code.
- **Scope** covers the Linux Maven build. The image has no container
  runtime for upstream image publishing. Live registration against a
  Wanaku server and release jobs require external services or credentials.

Before running the bot, create the fork and the upstream
`needs-implementation` label. If you add assignee-based intake, give
`orp-bot` access to the upstream repository first. See
[Running a bot](../../docs/running-a-bot.md) for the token and agent login.
The container listens on port 8765.
