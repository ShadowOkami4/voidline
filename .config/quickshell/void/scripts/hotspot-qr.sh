#!/bin/sh

if ! command -v qrencode >/dev/null 2>&1; then
    printf '%s\n' 'error|Install qrencode to share this network'
    exit 1
fi

IFS= read -r ssid || exit 1
IFS= read -r password || exit 1

[ -n "$ssid" ] || exit 1
[ ${#password} -ge 8 ] || exit 1

escape_wifi_value() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/;/\\;/g' \
        -e 's/,/\\,/g' \
        -e 's/:/\\:/g' \
        -e 's/"/\\"/g'
}

escaped_ssid="$(escape_wifi_value "$ssid")"
escaped_password="$(escape_wifi_value "$password")"
runtime_root="${XDG_RUNTIME_DIR:-/tmp}/voidline"
qr_path="$runtime_root/hotspot-qr.png"

install -d -m 700 "$runtime_root" || exit 1
umask 077
qrencode -t PNG -l M -s 10 -m 2 -o "$qr_path" \
    "WIFI:T:WPA;S:${escaped_ssid};P:${escaped_password};H:false;;" || exit 1
chmod 600 "$qr_path"
printf 'path|%s\n' "$qr_path"
