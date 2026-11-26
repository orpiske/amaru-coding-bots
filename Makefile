# `make check` is what CI and the coding bot run to validate a change.
# It needs yq v4 (https://github.com/mikefarah/yq) and, if installed,
# runs ShellCheck on the scripts.

SHELL_SCRIPTS = scripts/*.sh bin/amaru-bot install.sh tests/*.sh

.PHONY: check build install

check:
	scripts/check-bots.sh
	@for s in $(SHELL_SCRIPTS); do sh -n "$$s" || exit 1; done
	@if command -v shellcheck >/dev/null; then shellcheck $(SHELL_SCRIPTS); fi
	tests/amaru-bot.sh
	tests/install.sh

# Build one bot locally: make build BOT=wanaku [RUNTIME=docker]
RUNTIME ?= podman
build:
	@test -n "$(BOT)" || { echo "usage: make build BOT=<name>"; exit 2; }
	$(RUNTIME) build -f bots/$(BOT)/Containerfile -t localhost/amaru-light-$(BOT):dev bots/$(BOT)

# Install the amaru-bot CLI: make install [PREFIX=~/.local]
PREFIX ?= $(HOME)/.local
install:
	install -d $(PREFIX)/bin
	install -m 755 bin/amaru-bot $(PREFIX)/bin/amaru-bot
