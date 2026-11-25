# `make check` is what CI and the coding bot run to validate a change.

.PHONY: check build

check:
	python3 scripts/check-bots.py
	sh -n scripts/changed-bots.sh
	@if command -v shellcheck >/dev/null; then shellcheck scripts/*.sh; fi

# Build one bot locally: make build BOT=wanaku [RUNTIME=docker]
RUNTIME ?= podman
build:
	@test -n "$(BOT)" || { echo "usage: make build BOT=<name>"; exit 2; }
	$(RUNTIME) build -f bots/$(BOT)/Containerfile -t localhost/amaru-light-$(BOT):dev bots/$(BOT)
