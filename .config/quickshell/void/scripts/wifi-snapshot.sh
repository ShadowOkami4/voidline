#!/bin/sh

void_interface=${1:-}

if command -v nmcli >/dev/null 2>&1 \
        && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    printf 'backend|ready\n'
    printf 'backend-name|networkmanager\n'
    [ -n "$void_interface" ] || exit 0

    void_known_file=$(mktemp)
    trap 'rm -f -- "$void_known_file"' EXIT HUP INT TERM
    nmcli -g UUID connection show 2>/dev/null | while IFS= read -r uuid; do
        [ -n "$uuid" ] || continue
        type=$(nmcli -g connection.type connection show uuid "$uuid" 2>/dev/null || true)
        [ "$type" = 802-11-wireless ] || [ "$type" = wifi ] || continue
        ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null || true)
        [ -n "$ssid" ] || continue
        key_mgmt=$(nmcli -g 802-11-wireless-security.key-mgmt connection show uuid "$uuid" 2>/dev/null || true)
        case "$key_mgmt" in
            ''|none) security=open ;;
            *eap*|*8021x*) security=8021x ;;
            *) security=psk ;;
        esac
        printf '%s|%s\n' "$(printf '%s' "$ssid" | tr '|\t\r\n' '¦   ')" "$security"
    done > "$void_known_file"

    nmcli --mode multiline --colors no --escape no \
        --fields IN-USE,SSID,BSSID,SECURITY,SIGNAL,FREQ,DEVICE device wifi list \
        ifname "$void_interface" --rescan no 2>/dev/null |
        awk -v known_file="$void_known_file" '
            BEGIN {
                while ((getline known < known_file) > 0) {
                    separator = index(known, "|")
                    if (separator > 0)
                        is_known[substr(known, 1, separator - 1)] = 1
                }
                close(known_file)
            }
            function emit() {
                if (ssid == "") return
                gsub(/\|/, "¦", ssid)
                normal = tolower(security)
                if (normal == "" || normal == "--" || normal == "none") kind = "open"
                else if (normal ~ /802\.1x|eap/) kind = "enterprise"
                else if (normal ~ /owe/) kind = "owe"
                else if ((normal ~ /sae|wpa3/) && (normal ~ /wpa1|wpa2|psk/)) kind = "transition"
                else if (normal ~ /sae|wpa3/) kind = "sae"
                else if (normal ~ /wep/) kind = "wep"
                else kind = "psk"
                connected = in_use ~ /\*/ ? 1 : 0
                strength = signal + 0
                gsub(/\|/, "", bssid)
                gsub(/\|/, "", device)
                printf "network|%s|%s|%d|%d|%d|%s|%d|%s\n", ssid, kind, strength, connected, (ssid in is_known), bssid, frequency + 0, device
                in_use = ssid = bssid = security = signal = frequency = device = ""
            }
            /^IN-USE:/ { emit(); in_use = substr($0, index($0, ":") + 1); next }
            /^SSID:/ { ssid = substr($0, index($0, ":") + 1); sub(/^[[:space:]]+/, "", ssid); next }
            /^BSSID:/ { bssid = substr($0, index($0, ":") + 1); sub(/^[[:space:]]+/, "", bssid); next }
            /^SECURITY:/ { security = substr($0, index($0, ":") + 1); next }
            /^SIGNAL:/ { signal = substr($0, index($0, ":") + 1); next }
            /^FREQ:/ { frequency = substr($0, index($0, ":") + 1); next }
            /^DEVICE:/ { device = substr($0, index($0, ":") + 1); sub(/^[[:space:]]+/, "", device); next }
            END { emit() }
        '

    awk -F '|' 'NF >= 2 { printf "saved|%s|%s\n", $1, $2 }' "$void_known_file"
    exit 0
fi

if ! command -v iwctl >/dev/null 2>&1; then
    printf 'backend|missing\n'
    exit 0
fi

if ! systemctl is-active --quiet iwd 2>/dev/null; then
    printf 'backend|inactive\n'
    exit 0
fi

printf 'backend|ready\n'
printf 'backend-name|iwd\n'

if [ -z "$void_interface" ]; then
    exit 0
fi

void_known_file=$(mktemp)
trap 'rm -f -- "$void_known_file"' EXIT HUP INT TERM

iwctl known-networks list 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | awk '
        match($0, /[[:space:]]+(open|psk|8021x)[[:space:]]+/, columns) {
            name = substr($0, 1, RSTART - 1)
            gsub(/^[[:space:]>]+|[[:space:]]+$/, "", name)
            gsub(/\|/, "¦", name)
            if (name != "" && name != "Name") print name "|" columns[1]
        }
    ' > "$void_known_file"

iwctl station "$void_interface" get-networks rssi-dbms 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | awk -v known_file="$void_known_file" '
        BEGIN {
            while ((getline known < known_file) > 0) {
                split(known, saved, "|")
                is_known[saved[1]] = 1
            }
            close(known_file)
        }
        match($0, /[[:space:]]+(open|psk|8021x)[[:space:]]+(-?[0-9]+)[[:space:]]*$/, columns) {
            line = $0
            connected = line ~ /^[[:space:]]*>/
            name = substr(line, 1, RSTART - 1)
            gsub(/^[[:space:]>]+|[[:space:]]+$/, "", name)
            gsub(/\|/, "¦", name)
            dbm = columns[2] / 100
            strength = int((dbm + 100) * 2)
            if (strength < 1) strength = 1
            if (strength > 100) strength = 100
            if (name != "" && name != "Network name")
                printf "network|%s|%s|%d|%d|%d\n", name, columns[1], strength, connected, (name in is_known)
        }
    '

awk -F '|' '
    NF >= 2 { printf "saved|%s|%s\n", $1, $2 }
' "$void_known_file"
