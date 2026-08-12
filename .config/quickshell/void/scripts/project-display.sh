#!/bin/sh
set -eu

mode="${1:-extend}"
monitor_dump="$(hyprctl monitors all)"
monitors="$(printf '%s\n' "$monitor_dump" | awk '/^Monitor / { print $2 }')"
primary="$(printf '%s\n' "$monitors" | awk '/^eDP-/ { print; exit }')"
[ -n "$primary" ] || primary="$(printf '%s\n' "$monitors" | sed -n '1p')"
external="$(printf '%s\n' "$monitors" | awk -v primary="$primary" '$0 != primary { print; exit }')"

[ -n "$primary" ] || exit 1

validate_output() {
    case "$1" in
        *[!A-Za-z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}

monitor_mode() {
    printf '%s\n' "$monitor_dump" | awk -v target="$1" '
        /^Monitor / { selected = ($2 == target); next }
        selected && match($1, /^[0-9]+x[0-9]+@[0-9.]+$/) { print $1; exit }
    '
}

monitor_scale() {
    printf '%s\n' "$monitor_dump" | awk -v target="$1" '
        /^Monitor / { selected = ($2 == target); next }
        selected && $1 == "scale:" { print $2; exit }
    '
}

enable_monitor() {
    output="$1"
    position="$2"
    mirror="${3:-}"
    validate_output "$output" || exit 1
    [ -z "$mirror" ] || validate_output "$mirror" || exit 1

    output_mode="$(monitor_mode "$output")"
    output_scale="$(monitor_scale "$output")"
    [ -n "$output_mode" ] || output_mode="preferred"
    [ -n "$output_scale" ] || output_scale="1"
    case "$output_mode" in
        preferred|[0-9]*x[0-9]*@[0-9.]*) ;;
        *) output_mode=preferred ;;
    esac
    case "$output_scale" in
        *[!0-9.]*|'') output_scale=1 ;;
    esac
    case "$position" in
        0x0|auto-right) ;;
        *) exit 1 ;;
    esac

    if [ -n "$mirror" ]; then
        hyprctl eval "hl.monitor({ output = \"$output\", mode = \"$output_mode\", position = \"$position\", scale = $output_scale, disabled = false, mirror = \"$mirror\" })" >/dev/null
    else
        hyprctl eval "hl.monitor({ output = \"$output\", mode = \"$output_mode\", position = \"$position\", scale = $output_scale, disabled = false, mirror = \"\" })" >/dev/null
    fi
}

disable_monitor() {
    validate_output "$1" || exit 1
    hyprctl eval "hl.monitor({ output = \"$1\", disabled = true })" >/dev/null
}

case "$mode" in
    internal)
        enable_monitor "$primary" "0x0"
        for output in $monitors; do
            [ "$output" = "$primary" ] || disable_monitor "$output"
        done
        ;;
    external)
        [ -n "$external" ] || exit 1
        enable_monitor "$external" "0x0"
        for output in $monitors; do
            [ "$output" = "$external" ] || disable_monitor "$output"
        done
        ;;
    duplicate)
        [ -n "$external" ] || exit 1
        enable_monitor "$primary" "0x0"
        for output in $monitors; do
            [ "$output" = "$primary" ] || enable_monitor "$output" "0x0" "$primary"
        done
        ;;
    extend)
        [ -n "$external" ] || exit 1
        enable_monitor "$primary" "0x0"
        for output in $monitors; do
            [ "$output" = "$primary" ] || enable_monitor "$output" "auto-right"
        done
        ;;
    *)
        exit 2
        ;;
esac
