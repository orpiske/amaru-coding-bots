#!/bin/sh
# Replaces the original owner's accounts with yours in a fork or copy.
#
# The bots in this repository run as orp-bot, ask orpiske for reviews and
# push to quay.io/orpiske. Run this once after you fork or copy it:
#
#   scripts/make-it-yours.sh --bot my-bot --owner me
#   scripts/make-it-yours.sh --bot my-bot --owner me --group my-quay-org \
#       --repo me/amaru-coding-bots --dry-run
#
#   --bot     your bot's GitHub login (a separate account, not yours)
#   --owner   your GitHub login: the reviewer the bots listen to
#   --repo    your copy of this repository (default: from `git remote
#             origin`, else <owner>/amaru-coding-bots)
#   --group   your quay organization or user (default: --owner)
#   --dry-run list the files it would change, and change nothing
#
# It rewrites every tracked file except this script and the explanation
# between the `make-it-yours: keep` markers in README.md, then lists what
# you still have to do. Read the result with `git diff`.
set -eu

cd "$(dirname "$0")/.."

OLD_BOT=orp-bot
OLD_OWNER=orpiske
OLD_REPO=orpiske/amaru-coding-bots

usage() {
    sed -n '2,20s/^# \{0,1\}//p' "$0" >&2
    exit 2
}

bot='' owner='' repo='' group='' dry_run=0
while [ $# -gt 0 ]; do
    case "$1" in
        --bot) bot=${2:-}; shift 2 ;;
        --owner) owner=${2:-}; shift 2 ;;
        --repo) repo=${2:-}; shift 2 ;;
        --group) group=${2:-}; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage ;;
        *) echo "unknown argument: $1" >&2; usage ;;
    esac
done

[ -n "$bot" ] && [ -n "$owner" ] || usage

login_ok() {
    echo "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9-]{0,38}$'
}
login_ok "$bot" || { echo "--bot: '$bot' is not a GitHub login" >&2; exit 2; }
login_ok "$owner" || { echo "--owner: '$owner' is not a GitHub login" >&2; exit 2; }
if [ "$(echo "$bot" | tr '[:upper:]' '[:lower:]')" = "$(echo "$owner" | tr '[:upper:]' '[:lower:]')" ]; then
    echo "--bot and --owner must be different accounts: the bot needs its own" >&2
    exit 2
fi
if [ "$bot" = "$OLD_BOT" ]; then
    echo "--bot: $OLD_BOT is the original owner's bot; create your own" >&2
    exit 2
fi

if [ -z "$repo" ]; then
    url=$(git remote get-url origin 2>/dev/null || true)
    repo=$(echo "$url" | sed -n 's#^.*github\.com[:/]\([^/]*/[^/]*\)$#\1#p' | sed 's#\.git$##')
    [ -n "$repo" ] || repo=$owner/amaru-coding-bots
fi
echo "$repo" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' \
    || { echo "--repo: '$repo' is not owner/name" >&2; exit 2; }
[ -n "$group" ] || group=$owner

# One sed script, one command per line, so it works with GNU and BSD sed.
# The most specific names go first, so that `orpiske` inside the repository
# name and the quay path is not taken for the reviewer login. Lines between
# the keep markers are left alone.
script=$(mktemp)
tmp=$(mktemp)
trap 'rm -f "$script" "$tmp"' EXIT
cat > "$script" <<EOF
/<!-- make-it-yours: keep -->/,/<!-- make-it-yours: end -->/b
s#$OLD_REPO#$repo#g
s#quay\.io/$OLD_OWNER/#quay.io/$group/#g
s#'$OLD_OWNER'#'$group'#g
s#(default $OLD_OWNER)#(default $group)#g
s#| \`$OLD_OWNER\` |#| \`$group\` |#g
s#$OLD_BOT#$bot#g
s#$OLD_OWNER#$owner#g
EOF

self=scripts/make-it-yours.sh
count=0
changed=''
for f in $(git ls-files); do
    [ "$f" = "$self" ] && continue
    [ -f "$f" ] || continue
    grep -Iq . "$f" 2>/dev/null || continue          # skip binary files
    sed -f "$script" "$f" > "$tmp"
    if ! cmp -s "$f" "$tmp"; then
        count=$((count + 1))
        changed="$changed  $f
"
        [ "$dry_run" -eq 1 ] || cat "$tmp" > "$f"
    fi
done

if [ "$dry_run" -eq 1 ]; then verb="Would change"; else verb="Changed"; fi
printf '%s %s files:\n%s' "$verb" "$count" "$changed"
cat <<EOF

bot $bot, reviewer $owner, repository $repo, images quay.io/$group/

Still to do:
- Delete the bots under bots/ for projects you do not work on, and their
  rows in the README table.
- Fork each target repository as $bot ($bot/<repo>), including $repo,
  for the fork setup.
- In $repo: the needs-implementation label, the secrets QUAY_USERNAME
  and QUAY_PASSWORD, and the variable CONTAINER_GROUP=$group.
- Give $bot a token, as docs/running-a-bot.md says.
- make check, then git diff and commit.
EOF
