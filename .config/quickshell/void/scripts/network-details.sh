#!/bin/sh
set -eu

export LC_ALL=C

clean_field() {
    printf '%s' "$1" | tr '|\t\r\n' '    '
}

join_json_values() {
    jq -r 'map(select(length > 0)) | join(", ")' 2>/dev/null || true
}

snapshot() {
    interface_name=${1:-}
    requested_ssid=${2:-}
    case "$interface_name" in *[!A-Za-z0-9_.:-]*|'') exit 2 ;; esac
    [ -d "/sys/class/net/$interface_name" ] || exit 4

    interface_type=ethernet
    [ -d "/sys/class/net/$interface_name/wireless" ] && interface_type=wifi
    printf 'detail|type|%s\n' "$interface_type"
    printf 'detail|interface|%s\n' "$(clean_field "$interface_name")"

    if [ -r "/sys/class/net/$interface_name/address" ]; then
        printf 'detail|mac|%s\n' "$(clean_field "$(cat "/sys/class/net/$interface_name/address")")"
    fi
    if [ -r "/sys/class/net/$interface_name/operstate" ]; then
        printf 'detail|linkState|%s\n' "$(clean_field "$(cat "/sys/class/net/$interface_name/operstate")")"
    fi
    if [ -r "/sys/class/net/$interface_name/statistics/rx_bytes" ]; then
        printf 'detail|rxBytes|%s\n' "$(cat "/sys/class/net/$interface_name/statistics/rx_bytes")"
        printf 'detail|txBytes|%s\n' "$(cat "/sys/class/net/$interface_name/statistics/tx_bytes")"
    fi

    if command -v ip >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        addresses=$(ip -j address show dev "$interface_name" 2>/dev/null || printf '[]')
        ipv4=$(printf '%s' "$addresses" | jq -c '[.[].addr_info[]? | select(.family == "inet") | .local]' | join_json_values)
        ipv6=$(printf '%s' "$addresses" | jq -c '[.[].addr_info[]? | select(.family == "inet6" and .scope != "link") | .local]' | join_json_values)
        [ -n "$ipv4" ] && printf 'detail|ipv4|%s\n' "$(clean_field "$ipv4")"
        [ -n "$ipv6" ] && printf 'detail|ipv6|%s\n' "$(clean_field "$ipv6")"
        routes=$(ip -j route show default dev "$interface_name" 2>/dev/null || printf '[]')
        gateway=$(printf '%s' "$routes" | jq -r '.[0].gateway // empty' 2>/dev/null || true)
        [ -n "$gateway" ] && printf 'detail|gateway|%s\n' "$(clean_field "$gateway")"
    fi

    if command -v resolvectl >/dev/null 2>&1; then
        dns=$(resolvectl dns "$interface_name" 2>/dev/null |
            sed -n 's/^[^:]*:[[:space:]]*//p' | head -n 1)
        [ -n "$dns" ] && printf 'detail|dns|%s\n' "$(clean_field "$dns")"
    fi

    if [ "$interface_type" = wifi ] && command -v iw >/dev/null 2>&1; then
        link=$(iw dev "$interface_name" link 2>/dev/null || true)
        linked_ssid=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*SSID: //p' | head -n 1)
        frequency=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*freq: //p' | head -n 1)
        signal=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*signal: \([^ ]*\).*/\1/p' | head -n 1)
        bitrate=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*tx bitrate: //p' | head -n 1)
        channel=$(iw dev "$interface_name" info 2>/dev/null |
            sed -n 's/^[[:space:]]*channel \([0-9]*\).*/\1/p' | head -n 1)
        [ -n "$linked_ssid" ] || linked_ssid=$requested_ssid
        [ -n "$linked_ssid" ] && printf 'detail|ssid|%s\n' "$(clean_field "$linked_ssid")"
        [ -n "$frequency" ] && printf 'detail|frequency|%s\n' "$(clean_field "$frequency")"
        [ -n "$channel" ] && printf 'detail|channel|%s\n' "$(clean_field "$channel")"
        [ -n "$signal" ] && printf 'detail|signalDbm|%s\n' "$(clean_field "$signal")"
        [ -n "$bitrate" ] && printf 'detail|linkSpeed|%s\n' "$(clean_field "$bitrate")"
    fi

    if [ -x /usr/lib/voidline/network-secret-helper ]; then
        printf '%s\n' 'capability|secret-helper|1'
    else
        printf '%s\n' 'capability|secret-helper|0'
    fi
    if command -v qrencode >/dev/null 2>&1; then
        printf '%s\n' 'capability|qrencode|1'
    else
        printf '%s\n' 'capability|qrencode|0'
    fi
}

case "${1:-}" in
    snapshot)
        shift
        snapshot "${1:-}" "${2:-}"
        ;;
    *) exit 2 ;;
esac
