#!/bin/sh
# Tests install.sh from this checkout (file:// instead of GitHub), the way
# `curl ... | sh` runs it. Run by `make check`; needs curl.
set -eu

cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export AMARU_BOT_BASE_URL="file://$PWD"
export AMARU_BOT_CONFIG="$work/none"

failures=0
check() { # check <description> <command>...
    d=$1; shift
    if "$@"; then echo "ok   $d"; else echo "FAIL $d"; failures=$((failures + 1)); fi
}
installs() { sh -s -- "$@" < install.sh > "$work/out" 2>&1; }
says() { grep -q -- "$1" "$work/out"; }

check "installs through a pipe" installs --prefix "$work/p"
check "the installed file is bin/amaru-bot" cmp -s bin/amaru-bot "$work/p/bin/amaru-bot"
check "the installed file is executable" test -x "$work/p/bin/amaru-bot"
check "the installed CLI runs" sh -c "'$work/p/bin/amaru-bot' --help >/dev/null"
check "it says when the bin dir is not in PATH" says "is not in your PATH"
check "it points at amaru-bot init" says "amaru-bot init"

echo old > "$work/p/bin/amaru-bot"
check "running it again updates" installs --prefix="$work/p"
check "the update replaced the old file" cmp -s bin/amaru-bot "$work/p/bin/amaru-bot"

check "AMARU_BOT_PREFIX sets the prefix" sh -c "AMARU_BOT_PREFIX='$work/q' sh install.sh >/dev/null"
check "the AMARU_BOT_PREFIX install is there" test -x "$work/q/bin/amaru-bot"

mkdir -p "$work/bad/bin"
echo "<html>not found</html>" > "$work/bad/bin/amaru-bot"
check "a download that is not the script is refused" \
    sh -c "! AMARU_BOT_BASE_URL='file://$work/bad' sh install.sh --prefix '$work/r' >/dev/null 2>&1"
check "nothing is installed after a refusal" test ! -e "$work/r/bin/amaru-bot"
check "a missing file is refused" \
    sh -c "! AMARU_BOT_BASE_URL='file://$work/missing' sh install.sh --prefix '$work/r' >/dev/null 2>&1"
check "an unknown option is refused" sh -c "! sh install.sh --nope >/dev/null 2>&1"

if [ "$failures" -ne 0 ]; then
    echo "$failures test(s) failed"
    exit 1
fi
echo "all install.sh tests passed"
