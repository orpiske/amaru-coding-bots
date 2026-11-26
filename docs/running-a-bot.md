# Running a bot

Replace `<name>` with the bot's folder under `bots/`, `<port>` with the host
port for its web interface (the bot always listens on 8765 inside the
container; give each bot on one host its own host port),
`<bot>` with your bot account and `<group>` with your quay organization or
user. If you forked this repository, first replace the owner's accounts as
[Using this repository for your own bots](../README.md#using-this-repository-for-your-own-bots)
says.

## Before the first run

- A GitHub account for the bot, separate from yours. For the fork setup,
  its fork of the target repository, `<bot>/<repo>` (fork it while signed in as the bot).
- A token for the bot. For a fork onto a repository someone else owns, a
  classic token with `public_repo` (`repo` if the repository is private): a
  fine-grained token cannot open the pull request upstream. For direct
  push, a fine-grained token for the repository with Contents, Issues and
  Pull requests set to read and write.
- The intake label (`intake.labels` in `project.yaml`) on the target
  repository.
- Optional: a role for the bot on the target repository (triage is enough)
  so that it can add `amaru:working` and `amaru:blocked` and be assigned
  issues. Without it, blocked tickets resume with `amaru unblock <id>`.

## Get the image

Pull it (both architectures are published):

```sh
podman pull quay.io/<group>/amaru-light-<name>:latest
```

or build it from a checkout of this repository:

```sh
make build BOT=<name>        # localhost/amaru-light-<name>:dev
```

The settings are copied into the image, so pull or rebuild after a change
to the bot's `amaru.yaml` or `project.yaml`.

## Run with amaru-bot

[`bin/amaru-bot`](../bin/amaru-bot) wraps the `podman run` below. It keeps
the bot's token in a config file, gives every bot its own host port and
keeps that port across runs, so several bots run side by side:

```sh
make install                 # copies it to ~/.local/bin (PREFIX=... for elsewhere)
amaru-bot init               # writes ~/.config/amaru-bot/config (mode 600), asks for the token
amaru-bot run <name>         # Started <name> on http://127.0.0.1:8766 (...)
amaru-bot list               # every bot, its port and its state
amaru-bot status             # the running bots and their addresses
amaru-bot logs <name> -f
amaru-bot amaru <name> doctor
amaru-bot stop <name>        # or --all; the volume and the port are kept
```

The config file holds `key = value` lines; `amaru-bot --help` lists them
all:

```
gh_token = <bot token>                      # or: gh_token_command = pass show my-bot
image = quay.io/<group>/amaru-light-{bot}:latest
runtime = podman                            # or docker
bind = 127.0.0.1
first_port = 8766
```

For images built with `make build`, set
`image = localhost/amaru-light-{bot}:dev`, or set it for one bot only with
`<name>.image = ...`; `amaru-bot run <name> --image <image>` overrides it
once. `--port <port>` picks a host port and keeps it for the bot, and
`amaru-bot forget <name>` releases it. `amaru-bot run <name> --pull` pulls
a new image first; `amaru-bot restart <name> --pull` replaces a running bot.

The token goes to the runtime through its environment, never its command
line, and `amaru-bot` never prints it. It does not read `GH_TOKEN` from your
shell, which is most likely your own token; set `AMARU_BOT_GH_TOKEN` to
override the config for one run. Ports are recorded in
`~/.local/state/amaru-bot/ports`.

## Run by hand

```sh
export GH_TOKEN=<bot token>
podman run -d --name amaru-light-<name> \
  -e GH_TOKEN \
  -p 127.0.0.1:<port>:8765 \
  -v amaru-light-<name>:/home/mini-amaru:U \
  quay.io/<group>/amaru-light-<name>:latest
```

`-e GH_TOKEN` with no value copies the token from the shell, so it is not
in the command line or the history, and the volume never stores it. With
Docker, drop `:U` and make sure the volume is owned by uid 1000.

The volume holds the daemon state (`/home/mini-amaru/amaru`) and the agent
login. Keep it when you recreate the container for a new image.

## Sign the agent in

Once, on the web interface's Agents page (`http://127.0.0.1:<port>`), or:

```sh
podman exec -it amaru-light-<name> codex login --device-auth
podman exec -it amaru-light-<name> claude auth login
```

Optionally give the bot's commits its identity:

```sh
podman exec amaru-light-<name> git config --global user.name <bot>
podman exec amaru-light-<name> git config --global user.email <id>+<bot>@users.noreply.github.com
```

## Verify and give it work

```sh
podman exec amaru-light-<name> /app/bin/amaru -c /config/amaru.yaml doctor
```

Every line must start with `ok`. Then label an issue on the target
repository, or claim one:

```sh
podman exec amaru-light-<name> /app/bin/amaru -c /config/amaru.yaml claim '<owner>/<repo>#42'
```

Quote the reference: zsh treats `#` as a glob. Follow the work with
`podman logs -f amaru-light-<name>`, `amaru status` and the web interface.
