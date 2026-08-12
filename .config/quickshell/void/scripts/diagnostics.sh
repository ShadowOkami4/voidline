#!/bin/sh

set -eu

action="${1:-snapshot}"

snapshot() {
    detail="${1:-normal}"
    printf 'Voidline diagnostics\n'
    printf 'Generated: %s\n\n' "$(date --iso-8601=seconds)"
    printf 'Kernel: %s\n' "$(uname -srmo)"
    printf 'Session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
    printf 'Desktop: %s\n' "${XDG_CURRENT_DESKTOP:-unknown}"
    printf 'Quickshell: %s\n' "$(quickshell --version 2>/dev/null | head -n1 || printf unavailable)"
    printf 'Hyprland: %s\n' "$(hyprctl version -j 2>/dev/null | jq -r '.tag // .commit // "unknown"' 2>/dev/null || printf unavailable)"
    printf 'Ollama: %s\n' "$(systemctl --user is-active ollama.service 2>/dev/null || true)"
    printf 'Bluetooth: %s\n' "$(systemctl is-active bluetooth.service 2>/dev/null || true)"
    printf 'PipeWire: %s\n' "$(systemctl --user is-active pipewire.service 2>/dev/null || true)"
    printf 'WirePlumber: %s\n' "$(systemctl --user is-active wireplumber.service 2>/dev/null || true)"
    printf 'Package manager: pacman %s\n' "$(pacman --version 2>/dev/null | awk 'NR==2 {print $3; exit}' || printf unavailable)"
    printf '\nMonitors:\n'
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | "  \(.name): \(.width)x\(.height)@\(.refreshRate) scale \(.scale)"' 2>/dev/null || true
    printf '\nAudio:\n'
    wpctl status 2>/dev/null | sed -n '1,80p' || true
    printf '\nNetwork:\n'
    networkctl list --no-pager 2>/dev/null || true
    printf '\nBluetooth devices:\n'
    bluetoothctl devices 2>/dev/null || true
    printf '\nRecent Quickshell log:\n'
    if [ "$detail" = "verbose" ]; then
        journalctl --user -b --no-pager -n 500 -t quickshell 2>/dev/null || true
        printf '\nQuickshell service processes:\n'
        ps -u "$(id -u)" -o pid,etimes,pcpu,pmem,comm,args 2>/dev/null |
            grep -E 'quickshell|ollama|pipewire|wireplumber' || true
    else
        journalctl --user -b --no-pager -n 120 -t quickshell 2>/dev/null || true
    fi
}

export_report() {
    detail="${1:-normal}"
    directory="$HOME/Documents/Voidline/Diagnostics"
    mkdir -p "$directory"
    path="$directory/voidline-$(date +%Y%m%d-%H%M%S).txt"
    snapshot "$detail" > "$path"
    chmod 600 "$path"
    printf '%s\n' "$path"
}

clear_cache() {
    cache="$HOME/.cache/voidline"
    if [ -d "$cache" ]; then
        find "$cache" -mindepth 1 -maxdepth 1 -exec rm -r -- {} +
    fi
}

case "$action" in
    snapshot) snapshot "${2:-normal}" ;;
    export) export_report "${2:-normal}" ;;
    clear-cache) clear_cache ;;
    *) exit 2 ;;
esac
