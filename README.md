# amaru-coding-bots

Coding bots for the projects I work on. Each bot is an
[Amaru Light](https://github.com/amaru-oss/amaru-light) daemon in its own
container image, built on the Amaru Light base image with the toolchain its
project needs. It works on that project's issues as my bot account,
`orp-bot`, and opens pull requests; it never merges. To run them as your
own bot, see [below](#using-this-repository-for-your-own-bots).

## Bots

| Bot | Repository | Agent | Image |
| --- | --- | --- | --- |
| [amaru-coding-bots](bots/amaru-coding-bots) | orpiske/amaru-coding-bots | Codex | `quay.io/orpiske/amaru-light-amaru-coding-bots` |
| [camel-integration-capability](bots/camel-integration-capability) | wanaku-ai/camel-integration-capability | Codex | `quay.io/orpiske/amaru-light-camel-integration-capability` |
| [midnight-saci](bots/midnight-saci) | orpiske/midnight-saci | Codex | `quay.io/orpiske/amaru-light-midnight-saci` |
| [rhaf-portal-core](bots/rhaf-portal-core) | rhaf-ai/rhaf-portal-core | Codex | `quay.io/orpiske/amaru-light-rhaf-portal-core` |
| [wanaku](bots/wanaku) | wanaku-ai/wanaku | Codex | `quay.io/orpiske/amaru-light-wanaku` |

Every image has both Codex and Claude Code, and every `amaru.yaml` defines
both agents; the Agent column is the one `project.yaml` uses. Switch a bot
by setting `agent: claude` (or `codex`) in its `project.yaml`.

Every bot listens on 8765 inside its own container (`web.listen:
0.0.0.0:8765`, `EXPOSE 8765`), and `make check` enforces it. To run
several bots on one host, give each its own host port with
`-p 127.0.0.1:<host port>:8765`.

## Layout

```
bots/<name>/
  Containerfile   FROM ${BASE_IMAGE} (ghcr.io/amaru-oss/amaru-light:latest)
  amaru.yaml      daemon settings: state dir, web port, agents (codex and claude)
  project.yaml    the project: repo, fork, intake label, checks, review
  README.md       what the bot does and what its image cannot run
```

## Adding a bot

Open an issue with the **New coding bot** template. It is labelled
`needs-implementation`, so this repository's own bot
([bots/amaru-coding-bots](bots/amaru-coding-bots)) picks it up, inspects
the target project, writes `bots/<name>/` as [AGENTS.md](AGENTS.md) says
and opens a pull request. CI builds the new image on both architectures on
that pull request.

By hand: copy an existing folder, change it, and run `make check`.

## Images

[Build bots](.github/workflows/build-bots.yml) builds each image natively
on `ubuntu-latest` (x86_64) and `ubuntu-24.04-arm` (aarch64) and publishes
a multi-arch manifest:

- pull requests build the bots they change, and push nothing;
- pushes to `main` push the bots they change as `latest` and the commit
  SHA (a `ci-*` branch pushes its branch name);
- a manual run rebuilds every bot, or the ones you name; run it after a
  new base image is published.

It uses the same settings as wanaku-ai/wanaku:

| Name | Kind | Default |
| --- | --- | --- |
| `CONTAINER_REGISTRY` | variable | `quay.io` |
| `CONTAINER_GROUP` | variable | `orpiske` |
| `QUAY_USERNAME` | secret | none: build without pushing |
| `QUAY_PASSWORD` | secret | none: build without pushing |

To build one bot locally: `make build BOT=<name>` (Podman; add
`RUNTIME=docker` for Docker).

## Using this repository for your own bots

<!-- make-it-yours: keep -->
The bots here run as **my** bot account, `orp-bot`, ask **me** (`orpiske`)
for reviews and push images to `quay.io/orpiske`. They will not work for
you as they are: `orp-bot` is mine, and its token is not yours to have.
Create your own bot account (a separate GitHub account, not your own),
fork or copy this repository, and run:

```sh
scripts/make-it-yours.sh --bot <your-bot> --owner <you> [--group <quay org>] [--dry-run]
```

It replaces `orp-bot` (the `bot_login`, the forks `orp-bot/<repo>`),
`orpiske` (the reviewers), `orpiske/amaru-coding-bots` (this repository's
own bot) and `quay.io/orpiske` (the images and the `CONTAINER_GROUP`
default) in every file, then lists what is left to do: delete the bots for
projects you do not work on, fork the target repositories as your bot,
create the `needs-implementation` label, set the quay secrets and give your
bot its token as [Running a bot](docs/running-a-bot.md) says.

The self-hosting bot takes the bot login and reviewers from
`bots/amaru-coding-bots/` for every new bot it writes, so once that folder
is yours, new bots are too.
<!-- make-it-yours: end -->

## Running a bot

See [Running a bot](docs/running-a-bot.md).
