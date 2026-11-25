# amaru-coding-bots bot

The coding bot for this repository. `orp-bot` picks issues labelled
`needs-implementation`, writes or changes a bot folder under `bots/` with
Codex as [AGENTS.md](../../AGENTS.md) describes, runs `make check`, pushes
to its fork `orp-bot/amaru-coding-bots` and opens a pull request. CI builds
the changed images on that pull request. It never merges.

- Repository: `orpiske/amaru-coding-bots` (fork `orp-bot/amaru-coding-bots`)
- Agent: Codex
- Checks: `make check`
- Web interface: port 8765 in the container (publish it on any host port)

To run it, see [Running a bot](../../docs/running-a-bot.md).
