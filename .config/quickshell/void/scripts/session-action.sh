#!/bin/sh

set -eu

case "${1:-}" in
    lock)
        exec qs -p "$HOME/.config/quickshell/void" ipc call lockScreen lock
        ;;
    suspend)
        exec systemctl suspend
        ;;
    logout)
        if command -v hyprshutdown >/dev/null 2>&1; then
            exec hyprshutdown
        fi
        exec hyprctl eval 'hl.dispatch(hl.dsp.exit())'
        ;;
    reboot)
        exec systemctl reboot
        ;;
    poweroff)
        exec systemctl poweroff
        ;;
    *)
        exit 2
        ;;
esac
