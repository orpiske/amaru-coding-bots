#!/bin/sh
# Prints, as a JSON array, the bots under bots/ whose image must be built.
#
#   scripts/changed-bots.sh <base> <head>   bots changed between two commits
#   scripts/changed-bots.sh --all           every bot
#   scripts/changed-bots.sh --only a b      the named bots (each must exist)
#
# A bot is a folder bots/<name>/ with a Containerfile. Markdown changes do
# not count. A change to a file that every build uses (the build workflow,
# this script) selects every bot, and so does a base that is missing or all
# zeros (a new branch, or a force push).
set -eu

cd "$(dirname "$0")/.."

all_bots() {
    for f in bots/*/Containerfile; do
        [ -f "$f" ] || continue
        basename "$(dirname "$f")"
    done
}

to_json() {
    printf '['
    sep=''
    while read -r bot; do
        [ -n "$bot" ] || continue
        printf '%s"%s"' "$sep" "$bot"
        sep=','
    done
    printf ']\n'
}

case "${1:-}" in
    --all)
        all_bots | to_json
        exit 0 ;;
    --only)
        shift
        for bot in "$@"; do
            if [ ! -f "bots/$bot/Containerfile" ]; then
                echo "No bot named '$bot' (bots/$bot/Containerfile is missing)" >&2
                exit 1
            fi
        done
        printf '%s\n' "$@" | sort -u | to_json
        exit 0 ;;
esac

if [ $# -ne 2 ]; then
    echo "usage: $0 <base> <head> | --all | --only <bot>..." >&2
    exit 2
fi
base=$1
head=$2

case "$base" in
    ''|0000000000000000000000000000000000000000)
        all_bots | to_json
        exit 0 ;;
esac
if ! git cat-file -e "$base^{commit}" 2>/dev/null; then
    echo "Base $base is not in the clone; building every bot" >&2
    all_bots | to_json
    exit 0
fi

changed=$(git diff --name-only "$base" "$head")

if printf '%s\n' "$changed" | grep -qx -e '.github/workflows/build-bots.yml' -e 'scripts/changed-bots.sh'; then
    all_bots | to_json
    exit 0
fi

printf '%s\n' "$changed" \
    | grep -v '\.md$' \
    | sed -n 's|^bots/\([^/]*\)/.*|\1|p' \
    | sort -u \
    | while read -r bot; do
        [ -f "bots/$bot/Containerfile" ] && echo "$bot"
    done \
    | to_json
