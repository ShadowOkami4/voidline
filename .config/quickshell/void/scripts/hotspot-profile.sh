#!/bin/sh

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/voidline"
profile_path="$state_root/hotspot.profile"

decode_line() {
    printf '%s' "$1" | base64 -d 2>/dev/null
}

case "${1:-}" in
    read)
        if [ ! -r "$profile_path" ]; then
            exit 0
        fi

        ssid_encoded="$(sed -n '1p' "$profile_path")"
        password_encoded="$(sed -n '2p' "$profile_path")"
        band="$(sed -n '3p' "$profile_path")"
        ssid="$(decode_line "$ssid_encoded")"
        password="$(decode_line "$password_encoded")"

        if [ -n "$ssid" ] && [ ${#password} -ge 8 ]; then
            printf 'ssid|%s\n' "$ssid"
            printf 'password|%s\n' "$password"
            printf 'band|%s\n' "${band:-2.4}"
        fi
        ;;
    write)
        IFS= read -r ssid || exit 1
        IFS= read -r password || exit 1
        IFS= read -r band || exit 1

        [ -n "$ssid" ] || exit 1
        [ ${#password} -ge 8 ] || exit 1
        [ ${#password} -le 63 ] || exit 1

        install -d -m 700 "$state_root" || exit 1
        umask 077
        temporary_path="$profile_path.tmp.$$"
        trap 'rm -f "$temporary_path"' EXIT HUP INT TERM
        {
            printf '%s' "$ssid" | base64 -w 0
            printf '\n'
            printf '%s' "$password" | base64 -w 0
            printf '\n%s\n' "${band:-2.4}"
        } > "$temporary_path" || exit 1
        chmod 600 "$temporary_path" || exit 1
        mv -f "$temporary_path" "$profile_path" || exit 1
        printf '%s\n' 'saved|1'
        ;;
    *)
        printf '%s\n' 'usage: hotspot-profile.sh read|write' >&2
        exit 2
        ;;
esac
