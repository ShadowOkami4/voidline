#!/bin/sh

set -eu

action="${1:-snapshot}"

snapshot() {
    firewall="unavailable"
    firewall_service=""
    if systemctl list-unit-files firewalld.service --no-legend 2>/dev/null | grep -q firewalld; then
        firewall_service="firewalld"
        firewall="$(systemctl is-active firewalld.service 2>/dev/null || true)"
    elif command -v ufw >/dev/null 2>&1; then
        firewall_service="ufw"
        if [ -r /etc/ufw/ufw.conf ] &&
            grep -Eq '^[[:space:]]*ENABLED=yes[[:space:]]*$' /etc/ufw/ufw.conf; then
            firewall="active"
        else
            firewall="inactive"
        fi
    fi
    printf 'firewall|%s|%s\n' "$firewall_service" "$firewall"

    secure_boot="unsupported"
    if [ -d /sys/firmware/efi ]; then
        secure_boot="$(bootctl status 2>/dev/null |
            awk -F: '/Secure Boot:/ {gsub(/^[ \t]+/,"",$2); print tolower($2); exit}')"
        [ -n "$secure_boot" ] || secure_boot="unknown"
    fi
    printf 'secureboot|%s\n' "$secure_boot"

    root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    encryption="not detected"
    if printf '%s' "$root_source" | grep -q '/mapper/'; then
        encryption="encrypted"
    elif lsblk -rno TYPE,FSTYPE 2>/dev/null | grep -q '^crypt '; then
        encryption="encrypted"
    fi
    printf 'encryption|%s|%s\n' "$encryption" "$root_source"

    sessions="$(loginctl list-sessions --no-legend 2>/dev/null | awk 'NF {count++} END {print count+0}')"
    printf 'sessions|%s\n' "$sessions"

    idle_config="$HOME/.config/hypr/hypridle.conf"
    timeout="$(awk '/^[ \t]*timeout[ \t]*=/ {gsub(/[^0-9]/,"",$0); print; exit}' "$idle_config" 2>/dev/null || true)"
    [ -n "$timeout" ] || timeout=300
    printf 'lock-timeout|%s\n' "$timeout"

    command -v journalctl >/dev/null 2>&1 && printf '%s\n' "cap|journal|1"
    command -v firewall-cmd >/dev/null 2>&1 && printf '%s\n' "cap|firewalld|1"
}

set_lock_timeout() {
    seconds="${1:-}"
    case "$seconds" in ''|*[!0-9]*) exit 2 ;; esac
    [ "$seconds" -ge 30 ] && [ "$seconds" -le 86400 ] || exit 2
    config="$HOME/.config/hypr/hypridle.conf"
    [ -f "$config" ] || exit 3
    directory="$(dirname "$config")"
    temporary="$(mktemp "$directory/.voidline-hypridle.XXXXXX")" || exit 3
    trap 'rm -f "$temporary"' EXIT HUP INT TERM
    if ! awk -v seconds="$seconds" '
        BEGIN { replaced=0 }
        /^[ \t]*timeout[ \t]*=/ && !replaced {
            match($0, /^[ \t]*/)
            indent=substr($0, RSTART, RLENGTH)
            print indent "timeout = " seconds
            replaced=1
            next
        }
        { print }
    ' "$config" > "$temporary"; then
        exit 3
    fi
    chmod --reference="$config" "$temporary" 2>/dev/null || true
    mv "$temporary" "$config"
    trap - EXIT HUP INT TERM
    if command -v hyprctl >/dev/null 2>&1; then
        pkill -x hypridle 2>/dev/null || true
        if systemctl --user cat hypridle.service >/dev/null 2>&1; then
            systemctl --user restart hypridle.service
        else
            hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("hypridle"))' \
                >/dev/null 2>&1 || true
        fi
    fi
}

firewall_action() {
    requested="${1:-}"
    [ "$requested" = "start" ] || [ "$requested" = "stop" ] || exit 2
    if systemctl list-unit-files firewalld.service --no-legend 2>/dev/null |
        grep -q firewalld; then
        if [ "$requested" = "start" ]; then
            exec pkexec /usr/bin/systemctl enable --now firewalld.service
        fi
        exec pkexec /usr/bin/systemctl disable --now firewalld.service
    fi
    if command -v ufw >/dev/null 2>&1; then
        if [ "$requested" = "start" ]; then
            exec pkexec /usr/bin/ufw --force enable
        fi
        exec pkexec /usr/bin/ufw --force disable
    fi
    exit 4
}

case "$action" in
    snapshot) snapshot ;;
    lock-timeout) set_lock_timeout "${2:-}" ;;
    firewall) firewall_action "${2:-}" ;;
    *) exit 2 ;;
esac
