# Running a bot

Replace `<name>` with the bot's folder under `bots/`, and `<port>` with its
web port (`web.listen` in its `amaru.yaml`, and the table in the README).

## Before the first run

- The bot account `orp-bot`. For the fork setup, its fork of the target
  repository, `orp-bot/<repo>` (fork it while signed in as the bot).
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
podman pull quay.io/orpiske/amaru-light-<name>:latest
```

or build it from a checkout of this repository:

```sh
make build BOT=<name>        # localhost/amaru-light-<name>:dev
```

The settings are copied into the image, so pull or rebuild after a change
to the bot's `amaru.yaml` or `project.yaml`.

## Run

```sh
export GH_TOKEN=<orp-bot token>
podman run -d --name amaru-light-<name> \
  -e GH_TOKEN \
  -p 127.0.0.1:<port>:<port> \
  -v amaru-light-<name>:/home/mini-amaru:U \
  quay.io/orpiske/amaru-light-<name>:latest
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
podman exec amaru-light-<name> git config --global user.name orp-bot
podman exec amaru-light-<name> git config --global user.email <id>+orp-bot@users.noreply.github.com
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
