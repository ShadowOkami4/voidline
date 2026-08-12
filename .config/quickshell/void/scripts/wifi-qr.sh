#!/bin/sh
set -eu

escape_wifi() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/;/\\;/g; s/,/\\,/g; s/:/\\:/g; s/"/\\"/g'
}

[ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ] || exit 3
runtime_directory=$XDG_RUNTIME_DIR
qr_path=$runtime_directory/voidline-wifi-share.png

case "${1:-}" in
    generate)
        ssid=${2:-}
        security=${3:-WPA}
        IFS= read -r passphrase || passphrase=
        [ -n "$ssid" ] || exit 2
        command -v qrencode >/dev/null 2>&1 || exit 127
        case "$security" in
            open|none|NONE) qr_security=nopass ;;
            *) qr_security=WPA ;;
        esac
        qr_data="WIFI:T:$qr_security;S:$(escape_wifi "$ssid");P:$(escape_wifi "$passphrase");;"
        umask 077
        qrencode -t PNG -l M -s 10 -m 2 -o "$qr_path" "$qr_data"
        chmod 600 "$qr_path"
        printf 'path|%s\n' "$qr_path"
        printf 'data|%s\n' "$qr_data"
        ;;
    save)
        ssid=${2:-Wi-Fi}
        source_path=${3:-}
        [ "$source_path" = "$qr_path" ] && [ -f "$source_path" ] || exit 2
        safe_name=$(printf '%s' "$ssid" | tr -c 'A-Za-z0-9._-' '_' | cut -c 1-64)
        pictures=${XDG_PICTURES_DIR:-"$HOME/Pictures"}
        install -d -m 700 "$pictures"
        destination=$pictures/${safe_name:-Wi-Fi}-QR.png
        install -m 600 "$source_path" "$destination"
        printf '%s\n' "$destination"
        ;;
    clear)
        source_path=${2:-}
        [ "$source_path" = "$qr_path" ] || exit 2
        rm -f -- "$source_path"
        ;;
    *) exit 2 ;;
esac
