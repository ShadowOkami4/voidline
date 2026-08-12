#!/bin/sh

set -eu

action="${1:-list}"

list_updates() {
    if command -v checkupdates >/dev/null 2>&1; then
        checkupdates 2>/dev/null |
            awk 'NF >= 4 {
                old=$2
                new=$4
                print "package|official|" $1 "|" old "|" new
            }' || true
    else
        printf '%s\n' "status|missing|Install pacman-contrib to check repository updates"
    fi

    if command -v yay >/dev/null 2>&1; then
        yay -Qua 2>/dev/null |
            awk 'NF >= 4 {
                old=$2
                new=$4
                print "package|aur|" $1 "|" old "|" new
            }' || true
    else
        printf '%s\n' "status|aur-missing|yay is not installed"
    fi
}

install_official() {
    command -v pkexec >/dev/null 2>&1 || {
        printf '%s\n' "Polkit is unavailable" >&2
        exit 4
    }
    [ -x /usr/bin/pacman ] || exit 5
    exec pkexec /usr/bin/pacman --noconfirm --needed -Syu
}

case "$action" in
    list|refresh) list_updates ;;
    install-official) install_official ;;
    *) exit 2 ;;
esac
