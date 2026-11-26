#!/bin/sh
# Tests bin/amaru-bot against a fake container runtime and a fake `ss`,
# so it needs neither Podman nor a free port. Run by `make check`.
set -eu

cd "$(dirname "$0")/.."
BIN=$PWD/bin/amaru-bot

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/containers"
export AMARU_BOT_CONFIG="$work/config"
export AMARU_BOT_STATE="$work/state"
export FAKE_DIR="$work"
export PATH="$work/bin:$PATH"
# A token in the shell must never reach a bot.
export GH_TOKEN=personal-token-must-not-be-used
TOKEN=bot-token-0123456789

# The fake runtime: one file per container, holding "state port image".
cat > "$work/bin/podman" <<'FAKE'
#!/bin/sh
printf '%s\n' "$*" >> "$FAKE_DIR/argv"
c=$FAKE_DIR/containers
case "$1" in
    container)
        # container inspect --format <format> <name>
        f=$4 n=$5
        [ -f "$c/$n" ] || exit 1
        read -r state port image < "$c/$n"
        case "$f" in
            *State.Status*) echo "$state" ;;
            *amaru-bot.port*) echo "$port" ;;
            *amaru-bot.bot*) echo "${n#amaru-light-}" ;;
            *Config.Image*) echo "$image"; echo "started:   now" ;;
        esac ;;
    ps)
        for f in "$c"/*; do [ -f "$f" ] && basename "$f"; done; true ;;
    run)
        shift
        name='' port='' image=''
        while [ $# -gt 0 ]; do
            case "$1" in
                --name) name=$2; shift 2 ;;
                --label) case "$2" in amaru-bot.port=*) port=${2#*=} ;; esac; shift 2 ;;
                -p|-e|-v) shift 2 ;;
                -*) shift ;;
                *) image=$1; shift ;;
            esac
        done
        printf 'GH_TOKEN=%s\n' "${GH_TOKEN:-}" > "$FAKE_DIR/env.$name"
        echo "running $port $image" > "$c/$name"
        echo 0123abcd ;;
    stop) rm -f "$c/$2" ;;
    rm) rm -f "$c/$2" ;;
    logs) echo "logs of $*" ;;
    exec) echo "exec $*" ;;
    pull) ;;
esac
FAKE
# The fake ss: lists the ports in $FAKE_DIR/busy as listening.
cat > "$work/bin/ss" <<'FAKE'
#!/bin/sh
[ -f "$FAKE_DIR/busy" ] || exit 0
while read -r p; do echo "LISTEN 0 4096 127.0.0.1:$p 0.0.0.0:*"; done < "$FAKE_DIR/busy"
FAKE
chmod +x "$work/bin/podman" "$work/bin/ss"

failures=0
ok() { echo "ok   $*"; }
bad() { echo "FAIL $*"; failures=$((failures + 1)); }
check() { # check <description> <command>...
    d=$1; shift
    if "$@"; then ok "$d"; else bad "$d"; fi
}
out() { "$BIN" "$@" 2>&1; }
fails() { ! "$BIN" "$@" >/dev/null 2>&1; }
has() { printf "%s\n" "$1" | grep -q -- "$2"; }
not_in() { ! grep -q -- "$1" "$2"; }

camel_project=$("${YQ:-yq}" '[.repo, .base_branch, .fork, .agent] | @tsv' bots/camel/project.yaml)
check "Camel targets upstream main from the bot fork with Claude Code" \
    test "$camel_project" = "$(printf 'apache/camel\tmain\torp-bot/camel\tclaude')"
camel_intake=$("${YQ:-yq}" '[.jira.url, .jira.project, .jira.comment, .intake.labels[]] | @tsv' bots/camel/project.yaml)
check "Camel polls ASF Jira for labelled CAMEL tickets with comments disabled" \
    test "$camel_intake" = "$(printf 'https://issues.apache.org/jira\tCAMEL\tfalse\tneeds-implementation')"

check "run without a token fails" fails run midnight-saci

cat > "$AMARU_BOT_CONFIG" <<CFG
# test
gh_token = $TOKEN
first_port = 18766
wanaku.image = localhost/amaru-light-{bot}:dev
CFG
chmod 600 "$AMARU_BOT_CONFIG"

o=$(out run midnight-saci)
check "first bot gets the first port" test "$o" = "Started midnight-saci on http://127.0.0.1:18766 (quay.io/orpiske/amaru-light-midnight-saci:latest)"
check "the bot gets the configured token, not the shell's" grep -qx "GH_TOKEN=$TOKEN" "$work/env.amaru-light-midnight-saci"
check "run passes the command line the bot needs" grep -q -- "run --rm -d --name amaru-light-midnight-saci --label amaru-bot.bot=midnight-saci --label amaru-bot.port=18766 -p 127.0.0.1:18766:8765 -e GH_TOKEN -v amaru-light-midnight-saci:/home/mini-amaru:U quay.io/orpiske/amaru-light-midnight-saci:latest" "$work/argv"

o=$(out run midnight-saci)
check "a running bot is not started twice" test "$o" = "midnight-saci is already running on http://127.0.0.1:18766"

echo 18767 > "$work/busy"
o=$(out run wanaku)
check "the next bot skips taken and busy ports and uses its own image" test "$o" = "Started wanaku on http://127.0.0.1:18768 (localhost/amaru-light-wanaku:dev)"

check "--port of another bot is refused" fails run rhaf-portal-core --port 18766
check "a busy --port is refused" fails run rhaf-portal-core --port 18767
o=$(out run rhaf-portal-core --port 19000 --image localhost/x:1)
check "--port and --image are used" test "$o" = "Started rhaf-portal-core on http://127.0.0.1:19000 (localhost/x:1)"

o=$(out status)
check "status lists the running bots" has "$o" "^wanaku  *http://127.0.0.1:18768  *localhost/amaru-light-wanaku:dev"

o=$(out stop midnight-saci)
check "stop stops the bot" test "$o" = "Stopped midnight-saci"
o=$(out run midnight-saci)
check "a bot keeps its port across runs" test "$o" = "Started midnight-saci on http://127.0.0.1:18766 (quay.io/orpiske/amaru-light-midnight-saci:latest)"

o=$(out list)
check "list shows ports and states" has "$o" "^rhaf-portal-core  *19000  *running"

o=$(out restart wanaku)
check "restart runs the bot again on its port" test "$o" = "Started wanaku on http://127.0.0.1:18768 (localhost/amaru-light-wanaku:dev)"

check "forget refuses a running bot" fails forget wanaku
out stop --all >/dev/null
check "stop --all stops every bot" test -z "$(ls "$work/containers")"
out forget wanaku >/dev/null
check "forget releases the port" not_in "^wanaku " "$AMARU_BOT_STATE/ports"

check "a bad bot name is refused" fails run "../x"

o=$(out config)
check "config says the token is set" has "$o" "^gh_token:   set$"

AMARU_BOT_GH_TOKEN=override-token out run midnight-saci >/dev/null
check "AMARU_BOT_GH_TOKEN overrides the config" grep -qx "GH_TOKEN=override-token" "$work/env.amaru-light-midnight-saci"
out stop midnight-saci >/dev/null

sed -i.bak "s/^gh_token = .*/gh_token_command = printf '%s\\\\n' cmd-token/" "$AMARU_BOT_CONFIG"
out run midnight-saci >/dev/null
check "gh_token_command gives the token" grep -qx "GH_TOKEN=cmd-token" "$work/env.amaru-light-midnight-saci"

chmod 644 "$AMARU_BOT_CONFIG"
o=$(out config)
check "a readable config file is warned about" has "$o" "can be read by others"

check "no token is ever in a command line" not_in "$TOKEN\|override-token\|cmd-token\|personal-token" "$work/argv"

if [ "$failures" -ne 0 ]; then
    echo "$failures test(s) failed"
    exit 1
fi
echo "all amaru-bot tests passed"
