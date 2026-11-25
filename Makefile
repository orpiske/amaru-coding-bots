# `make check` is what CI and the coding bot run to validate a change.
# It needs yq v4 (https://github.com/mikefarah/yq) and, if installed,
# runs ShellCheck on the scripts.

.PHONY: check build

check:
	scripts/check-bots.sh
	@for s in scripts/*.sh; do sh -n "$$s" || exit 1; done
	@if command -v shellcheck >/dev/null; then shellcheck scripts/*.sh; fi

# Build one bot locally: make build BOT=wanaku [RUNTIME=docker]
RUNTIME ?= podman
build:
	@test -n "$(BOT)" || { echo "usage: make build BOT=<name>"; exit 2; }
	$(RUNTIME) build -f bots/$(BOT)/Containerfile -t localhost/amaru-light-$(BOT):dev bots/$(BOT)
