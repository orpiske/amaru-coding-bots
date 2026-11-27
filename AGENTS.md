# Working on amaru-coding-bots

This repository holds one coding bot per project: a folder `bots/<name>/`
with the image and settings of an [Amaru Light](https://github.com/amaru-oss/amaru-light)
daemon that works on that project's issues. CI builds every bot image for
linux/amd64 and linux/arm64 and pushes it to quay.io
(`.github/workflows/build-bots.yml`).

Most issues here ask for a new bot ("New coding bot" template) or a change
to an existing one. You work unattended: there is nobody to answer a
question while you work. When the issue leaves out something you cannot
find out yourself and cannot pick a safe default for, stop and say what is
missing, rather than guess.

## Sources of truth

Read these from the main branch of amaru-oss/amaru-light before you write a
bot, with `gh api repos/amaru-oss/amaru-light/contents/<path> --jq .content | base64 -d`
or a shallow clone into /tmp. When this file and those docs disagree,
follow the docs and say so in the pull request.

- docs/coding-bot-prompt.md: the full recipe for a bot. Follow its steps 1
  and 3 ("Inspect this project", "Write the files"); this file replaces
  steps 2, 4 and 5.
- docs/configuration.md: every key. Both YAML files are checked strictly,
  and an unknown key fails at startup.
- docs/building-project-containers.md, docs/github-access.md.
- coding-bot/ in amaru-light, and the existing folders under `bots/` here:
  copy their shape.

## Adding a bot

1. Read the issue. It names the repository, and may name the base branch,
   the setup (fork or direct push), the intake label, the agent, the check
   command and the reviewers. Use these defaults for what it leaves out.
   The bot account and the reviewers belong to whoever owns this copy of
   the repository: take them from this repository's own bot,
   `bots/amaru-coding-bots/amaru.yaml` (`bot_login`) and `project.yaml`
   (`review.reviewers`), never from another bot's folder or an example.
   - folder name: the repository name, lowercase (`bots/<name>/`);
   - the same `bot_login`, fork setup with fork `<bot login>/<repo name>`;
   - intake `labels: [needs-implementation]`, no assignee;
   - both agents defined in `amaru.yaml`: `codex` (driver codex,
     `args: [--dangerously-bypass-approvals-and-sandbox]`) and `claude`
     (driver claude, `args: [--permission-mode, bypassPermissions]`), with
     `agent: codex` in `project.yaml` unless the issue picks Claude Code;
   - in each agent, the `setup` steps that install the AI Agents OSS
     Helper plugin, copied from this repository's own bot
     (`bots/amaru-coding-bots/amaru.yaml`), plus any plugin or
     `instructions` file the issue asks for (see README.md, "Agent
     plugins and instructions");
   - the same `review.reviewers`, `review.self: same_agent`;
   - `state_dir: /home/mini-amaru/amaru`, `max_parallel: 1`,
     `poll_interval: 60s`, `branch_prefix: feat/`.
2. Inspect the target project: `git clone --depth 1 https://github.com/<owner>/<repo> /tmp/<repo>`.
   Read its AGENTS.md, CLAUDE.md, CONTRIBUTING, README, build manifests,
   toolchain pins and `.github/workflows`. Find the toolchains and exact
   versions CI uses, the system packages, and the one command (or short
   chain) that validates a change the way CI does. Prefer the project's own
   Makefile target or script. Leave out of the checks anything a container
   cannot run (a container runtime, a browser, a database, secrets) and
   list it in the bot's README.
3. The web port is always 8765 inside the container (`web.listen:
   0.0.0.0:8765`, `EXPOSE 8765`). Each bot runs in its own container, so
   the host port is chosen at run time with `-p`; `make check` enforces it.
4. Write `bots/<name>/`:
   - `Containerfile`: `ARG BASE_IMAGE=ghcr.io/amaru-oss/amaru-light:latest`,
     final stage `FROM ${BASE_IMAGE}`; the toolchain with `microdnf` (the
     base is Fedora Minimal) or from official images with `COPY --from=`;
     Node.js 22 and both agent CLIs, `@openai/codex` and
     `@anthropic-ai/claude-code` (every image has both, whichever agent the
     project uses); the gh Git credential helper; toolchains
     under /opt owned by `mini-amaru`; `COPY --chown=mini-amaru:mini-amaru amaru.yaml project.yaml /config/`;
     `USER mini-amaru`; a final RUN that prints every tool's version; and
     `EXPOSE 8765`. A header comment with the build, run and login
     commands. Everything must install on both x86_64 and aarch64: no
     downloads of a single-architecture binary. Pick the download by
     `uname -m` or `$TARGETARCH` when a tool has per-architecture releases.
   - `amaru.yaml`: the daemon file, with `web.listen: 0.0.0.0:8765` and
     `projects: [project.yaml]`.
   - `project.yaml`: the project file, with the checks from step 2 and
     timeouts that fit how long the project's CI takes.
   - `README.md`: what the bot does, its repository, agent, checks,
     and what its image cannot run.
5. Add a row for the bot to the table in README.md.
6. Run `make check`. It checks the layout, not the image: you have no
   container runtime here. CI builds the image on both architectures on
   your pull request; when that fails, read the job log and fix the
   Containerfile.
7. In the pull request, list the toolchain versions you pinned and where
   they come from, the check command, and what the owner still
   has to do: create the fork `<bot login>/<repo>`, give the bot a role if
   intake should use an assignee, and create the intake label on the
   target repository.

## Changing a bot

Change only the folder the issue is about. When a
target project moves to a new toolchain version, update the pin in the
Containerfile and say which file of the project you took it from.

## Rules

- Never put a token or any other secret in a file. The token comes from
  `GH_TOKEN` when the container starts.
- Do not change `.github/workflows/build-bots.yml` or `scripts/` unless the
  issue asks for it: a change there rebuilds every bot.
- Do not start, claim work for, or run any bot.
