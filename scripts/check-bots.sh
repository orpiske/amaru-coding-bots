#!/bin/sh
# Checks every bot folder under bots/ for the layout the build expects.
#
# Each bots/<name>/ must have a Containerfile, amaru.yaml, project.yaml and
# README.md, and:
# - <name> is lowercase letters, digits and dashes (it becomes the image name);
# - the Containerfile declares `ARG BASE_IMAGE=...`, builds its final stage
#   FROM ${BASE_IMAGE}, and copies amaru.yaml and project.yaml to /config/;
# - amaru.yaml and project.yaml parse, amaru.yaml has a state_dir and lists
#   project.yaml, the project's agent is defined in amaru.yaml, and the
#   project has a repo, an intake label or assignee, and checks;
# - every image has both agent CLIs: the Containerfile installs
#   @openai/codex and @anthropic-ai/claude-code and runs `codex --version`
#   and `claude --version`, and amaru.yaml defines an agent with driver
#   codex and one with driver claude;
# - web.listen is 0.0.0.0:<port>, the Containerfile EXPOSEs that port, and
#   no two bots share it, so they can all run on one host.
#
# It checks the layout only. CI builds the images, and Amaru Light checks
# every key when the daemon starts. Needs yq v4 (github.com/mikefarah/yq).
set -eu

cd "$(dirname "$0")/.."

YQ=${YQ:-yq}
if ! "$YQ" --version 2>/dev/null | grep -q 'mikefarah'; then
    echo "check-bots: needs yq v4 from https://github.com/mikefarah/yq (set YQ=<path> to point at it)" >&2
    exit 2
fi

errors=0
fail() {
    echo "error: $*" >&2
    errors=$((errors + 1))
}

ports=$(mktemp)
trap 'rm -f "$ports"' EXIT

found=0
for dir in bots/*/; do
    [ -d "$dir" ] || continue
    found=1
    dir=${dir%/}
    name=${dir#bots/}

    echo "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' \
        || fail "$dir: the name must be lowercase letters, digits and dashes"

    missing=0
    for f in Containerfile amaru.yaml project.yaml README.md; do
        if [ ! -f "$dir/$f" ]; then
            fail "$dir: $f is missing"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || continue

    cf=$dir/Containerfile
    grep -Eq '^ARG BASE_IMAGE=[^ ]+' "$cf" \
        || fail "$cf: needs 'ARG BASE_IMAGE=<default>' before FROM"
    # shellcheck disable=SC2016 # a literal ${BASE_IMAGE}
    [ "$(grep -E '^FROM ' "$cf" | tail -n 1 | sed 's/[[:space:]]*$//')" = 'FROM ${BASE_IMAGE}' ] \
        || fail "$cf: the final stage must be 'FROM \${BASE_IMAGE}'"
    grep -Eq '^COPY .*amaru\.yaml.*project\.yaml.*[[:space:]]/config/[[:space:]]*$' "$cf" \
        || fail "$cf: must COPY amaru.yaml project.yaml /config/"
    # Every bot image carries both agent CLIs, whichever one the project uses.
    for pkg in @openai/codex @anthropic-ai/claude-code; do
        grep -q "$pkg" "$cf" \
            || fail "$cf: must install $pkg (every image has Codex and Claude Code)"
    done
    for cli in codex claude; do
        grep -Eq "(^|[^[:alnum:]_-])$cli --version" "$cf" \
            || fail "$cf: the version check must run '$cli --version'"
    done

    daemon=$dir/amaru.yaml
    project=$dir/project.yaml
    parsed=1
    for y in "$daemon" "$project"; do
        if ! "$YQ" -e 'tag == "!!map"' "$y" >/dev/null 2>&1; then
            fail "$y: does not parse as a YAML mapping"
            parsed=0
        fi
    done
    [ "$parsed" -eq 1 ] || continue

    "$YQ" -e '.state_dir' "$daemon" >/dev/null 2>&1 \
        || fail "$daemon: state_dir is missing"
    "$YQ" -e '.projects[] | select(. == "project.yaml")' "$daemon" >/dev/null 2>&1 \
        || fail "$daemon: projects must list project.yaml"

    for driver in codex claude; do
        "$YQ" -e ".agents[] | select(.driver == \"$driver\")" "$daemon" >/dev/null 2>&1 \
            || fail "$daemon: needs an agent with driver $driver (every bot defines Codex and Claude Code)"
    done

    agent=$("$YQ" '.agent // ""' "$project")
    if [ -z "$agent" ]; then
        fail "$project: agent is missing"
    elif ! "$YQ" -e ".agents | has(\"$agent\")" "$daemon" >/dev/null 2>&1; then
        fail "$project: agent '$agent' is not defined in $daemon"
    fi

    "$YQ" '.repo // ""' "$project" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' \
        || fail "$project: repo must be owner/name"
    "$YQ" -e '(.intake.labels // [] | length) > 0 or (.intake.assignee // "") != ""' "$project" >/dev/null 2>&1 \
        || fail "$project: intake needs labels, an assignee or both"
    "$YQ" -e '(.checks // [] | length) > 0' "$project" >/dev/null 2>&1 \
        || fail "$project: no checks are defined"

    listen=$("$YQ" '.web.listen // ""' "$daemon")
    case "$listen" in
        '')
            fail "$daemon: web.listen is missing; give each bot its own port" ;;
        0.0.0.0:*)
            port=${listen#0.0.0.0:}
            grep -Eq "^EXPOSE[[:space:]]+$port([[:space:]]|\$)" "$cf" \
                || fail "$dir: web port $port is not EXPOSEd in the Containerfile"
            other=$(awk -v p="$port" '$1 == p { print $2 }' "$ports")
            if [ -n "$other" ]; then
                fail "$dir: web port $port is already used by bots/$other"
            fi
            echo "$port $name" >> "$ports" ;;
        *)
            fail "$daemon: web.listen must be 0.0.0.0:<port> to be reachable from the host" ;;
    esac
done

[ "$found" -eq 1 ] || fail "bots/: no bots found"

if [ "$errors" -gt 0 ]; then
    echo "$errors problem(s) found" >&2
    exit 1
fi
sort -n "$ports" | while read -r port name; do
    printf 'ok  %-24s port %s\n' "$name" "$port"
done
