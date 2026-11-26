#!/bin/sh
# Installs the amaru-bot CLI without a clone of this repository:
#
#   curl -fsSL https://raw.githubusercontent.com/orpiske/amaru-coding-bots/main/install.sh | sh
#
# Options, after `sh -s --` when piped (`... | sh -s -- --prefix /usr/local`):
#
#   --prefix <dir>  install into <dir>/bin (default: ~/.local)
#   --ref <ref>     the branch, tag or commit to install from (default: main)
#
# Run it again to update. AMARU_BOT_PREFIX and AMARU_BOT_REF set the same
# as the options; AMARU_BOT_BASE_URL replaces the whole download location
# (default: https://raw.githubusercontent.com/orpiske/amaru-coding-bots/<ref>).
#
# It downloads bin/amaru-bot with curl (or wget), checks that it is a shell
# script that parses, and installs it as <prefix>/bin/amaru-bot. It needs no
# root unless the prefix does, and it never asks for or touches a token.
set -eu

# Everything runs from main, called on the last line, so that a download
# cut short runs nothing.
main() {
    repo=orpiske/amaru-coding-bots
    prefix=${AMARU_BOT_PREFIX:-$HOME/.local}
    ref=${AMARU_BOT_REF:-main}
    while [ $# -gt 0 ]; do
        case "$1" in
            --prefix) [ $# -ge 2 ] || fail "--prefix needs a directory"; prefix=$2; shift 2 ;;
            --prefix=*) prefix=${1#--prefix=}; shift ;;
            --ref) [ $# -ge 2 ] || fail "--ref needs a branch, tag or commit"; ref=$2; shift 2 ;;
            --ref=*) ref=${1#--ref=}; shift ;;
            -h|--help)
                sed -n '2,17s/^# \{0,1\}//p' "$0" 2>/dev/null \
                    || echo "usage: install.sh [--prefix <dir>] [--ref <ref>]"
                exit 0 ;;
            *) fail "unknown option: $1 (options: --prefix <dir>, --ref <ref>)" ;;
        esac
    done
    base=${AMARU_BOT_BASE_URL:-https://raw.githubusercontent.com/$repo/$ref}
    url=$base/bin/amaru-bot
    dest=$prefix/bin/amaru-bot

    tmp=$(mktemp "${TMPDIR:-/tmp}/amaru-bot.XXXXXX")
    trap 'rm -f "$tmp"' EXIT INT TERM

    echo "Downloading $url"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$tmp" "$url" || fail "could not download $url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$tmp" "$url" || fail "could not download $url"
    else
        fail "needs curl or wget"
    fi

    [ "$(head -n 1 "$tmp")" = '#!/bin/sh' ] || fail "$url is not the amaru-bot script"
    sh -n "$tmp" || fail "$url does not parse as a shell script"

    mkdir -p "$prefix/bin" || fail "could not create $prefix/bin"
    # Write next to the target, then rename, so a running copy is not cut.
    if ! { cp "$tmp" "$dest.new.$$" && chmod 755 "$dest.new.$$" && mv -f "$dest.new.$$" "$dest"; }; then
        rm -f "$dest.new.$$"
        fail "could not write $dest"
    fi
    echo "Installed $dest"

    case ":$PATH:" in
        *":$prefix/bin:"*) ;;
        *) echo "Note: $prefix/bin is not in your PATH; add it, for example:"
           echo "  export PATH=\"$prefix/bin:\$PATH\"" ;;
    esac
    if [ ! -f "${AMARU_BOT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/amaru-bot/config}" ]; then
        echo "Next: amaru-bot init    (stores your bot's token), then: amaru-bot run <bot>"
    fi
}

fail() {
    echo "install.sh: $*" >&2
    exit 1
}

main "$@"
