# Apache Camel coding bot

The bot uses Claude Code on [CAMEL Jira tickets](https://issues.apache.org/jira/projects/CAMEL)
labelled `needs-implementation`. It pushes to `orp-bot/camel`, opens pull
requests against [apache/camel](https://github.com/apache/camel) on `main`,
and handles review feedback from `orpiske`.

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
affected by each pull request. The local check always builds Camel Core,
whatever module a change touches: a change to a component is checked only
by Camel's CI, which the bot follows through `fix_ci`, because Camel's
incremental-build action runs only on GitHub. The local check skips Failsafe integration
tests. The image has no Docker or Podman socket for Testcontainers, browser
setup, external test services, or release credentials.

Before running the bot, create the `orp-bot/camel` fork. Use the
`needs-implementation` label in ASF Jira to queue work. Follow Camel's
[ticket ownership rules](https://github.com/apache/camel/blob/main/AGENTS.md#jira-ticket-ownership)
when selecting tickets for the bot: assign and transition each ticket by
hand, since the bot has no Jira token to do it. It reads public Jira tickets anonymously
and Jira comments are disabled. See [Running a bot](../../docs/running-a-bot.md)
for the GitHub token and agent login. The container listens on port 8765.
