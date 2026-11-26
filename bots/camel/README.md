# Apache Camel coding bot

The bot uses Claude Code on issues labelled `needs-implementation` in
[apache/camel](https://github.com/apache/camel). It pushes to `orp-bot/camel`,
opens pull requests against `main`, and handles review feedback from
`orpiske`.

The image uses Eclipse Temurin 21 from Camel's required
[PR build job](https://github.com/apache/camel/blob/main/.github/workflows/pr-build-main.yml),
Maven 3.9.16 from Camel's
[wrapper configuration](https://github.com/apache/camel/blob/main/.mvn/wrapper/maven-wrapper.properties),
and Node.js 22 for Claude Code and Codex. Fedora's `ncurses-libs` supplies
the terminal library installed by Camel's PR workflow.

The 60-minute check builds Camel Core and its Maven reactor dependencies and
runs their unit tests.

```sh
./mvnw -B -ntp -pl core/camel-core -am -DskipITs install
```

Camel's hosted CI handles full repository regeneration and tests the modules
affected by each pull request. The local check skips Failsafe integration
tests. The image has no Docker or Podman socket for Testcontainers, browser
setup, external test services, or release credentials.

Before running the bot, create the `orp-bot/camel` fork and have an upstream
maintainer create the `needs-implementation` label. Assignee-based intake would
require giving `orp-bot` access to the upstream repository. See
[Running a bot](../../docs/running-a-bot.md) for the token and agent login.
The container listens on port 8765.
