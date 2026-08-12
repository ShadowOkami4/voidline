#!/bin/sh

if command -v wf-recorder >/dev/null 2>&1; then
    printf '%s\n' 'recorder|1'
else
    printf '%s\n' 'recorder|0'
fi

if command -v create_ap >/dev/null 2>&1 \
        && command -v hostapd >/dev/null 2>&1 \
        && command -v dnsmasq >/dev/null 2>&1; then
    printf 'hotspot|%s\n' "$(command -v create_ap)"
else
    printf '%s\n' 'hotspot|'
fi

if command -v qrencode >/dev/null 2>&1; then
    printf '%s\n' 'hotspot-qr|1'
else
    printf '%s\n' 'hotspot-qr|0'
fi
