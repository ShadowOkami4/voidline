#!/bin/sh

set -eu

command_name="${1:-snapshot}"

clamp_percent() {
    value="${1:-0}"
    case "$value" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$value" -lt 1 ] && value=1
    [ "$value" -gt 100 ] && value=100
    printf '%s\n' "$value"
}

active_graphical_session() {
    loginctl list-sessions --no-legend 2>/dev/null |
        while read -r session_id _rest; do
            [ -n "$session_id" ] || continue
            active="$(loginctl show-session "$session_id" -p Active --value 2>/dev/null || true)"
            remote="$(loginctl show-session "$session_id" -p Remote --value 2>/dev/null || true)"
            session_type="$(loginctl show-session "$session_id" -p Type --value 2>/dev/null || true)"
            seat="$(loginctl show-session "$session_id" -p Seat --value 2>/dev/null || true)"
            if [ "$active" = "yes" ] && [ "$remote" != "yes" ] &&
                    [ -n "$seat" ] &&
                    { [ "$session_type" = "wayland" ] || [ "$session_type" = "x11" ]; }; then
                printf '%s\n' "$session_id"
                break
            fi
        done
}

session_object_path() {
    session_id="$1"
    busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager GetSession s "$session_id" 2>/dev/null |
        awk -F'"' 'NF >= 2 { print $2; exit }'
}

snapshot_internal() {
    if ! command -v brightnessctl >/dev/null 2>&1; then
        printf '%s\n' "status|missing|brightnessctl is not installed"
        return
    fi

    found=0
    brightnessctl -m 2>/dev/null |
        while IFS=, read -r device class current maximum percent; do
            [ "$class" = "backlight" ] || continue
            found=1
            numeric_percent="${percent%%%}"
            printf 'device|internal|%s|%s|%s|%s|Built-in display\n' \
                "$device" "$numeric_percent" "$current" "$maximum"
        done

    # A second inexpensive check is necessary because a pipeline's variables
    # live in a subshell on POSIX sh.
    if ! brightnessctl -m 2>/dev/null | grep -q ',backlight,'; then
        printf '%s\n' "status|unsupported|No controllable internal display"
    fi
}

snapshot_external() {
    if ! command -v ddcutil >/dev/null 2>&1; then
        printf '%s\n' "status|missing|ddcutil is not installed"
        return
    fi

    ddcutil detect --brief 2>/dev/null |
        awk '
            /^Display [0-9]+/ { display=$2 }
            /^[[:space:]]*I2C bus:/ {
                bus=$3
                sub("^/dev/i2c-", "", bus)
                if (display != "" && bus != "")
                    print display "|" bus
            }
        ' |
        while IFS='|' read -r display bus; do
            value="$(ddcutil --bus "$bus" getvcp 10 --terse 2>/dev/null || true)"
            current="$(printf '%s\n' "$value" | awk '{ for (i=1;i<=NF;i++) if ($i ~ /^current=/) { sub("current=","",$i); print $i; exit } }')"
            maximum="$(printf '%s\n' "$value" | awk '{ for (i=1;i<=NF;i++) if ($i ~ /^max=/) { sub("max=","",$i); print $i; exit } }')"
            [ -n "$current" ] || continue
            [ -n "$maximum" ] || maximum=100
            percent=$((current * 100 / maximum))
            printf 'device|external|ddc-%s|%s|%s|%s|External display %s\n' \
                "$bus" "$percent" "$current" "$maximum" "$display"
        done
}

set_internal() {
    device="${1:-}"
    percent="$(clamp_percent "${2:-}")" || {
        printf '%s\n' "Invalid brightness value" >&2
        exit 2
    }
    case "$device" in
        ''|*[!A-Za-z0-9._:-]*)
            printf '%s\n' "Invalid backlight device" >&2
            exit 2
            ;;
    esac

    maximum_file="/sys/class/backlight/$device/max_brightness"
    [ -r "$maximum_file" ] || {
        printf '%s\n' "Backlight device is no longer available" >&2
        exit 3
    }
    maximum="$(sed -n '1p' "$maximum_file")"
    case "$maximum" in
        ''|*[!0-9]*) exit 3 ;;
    esac
    raw=$((maximum * percent / 100))
    [ "$raw" -lt 1 ] && raw=1

    session_id="$(active_graphical_session)"
    [ -n "$session_id" ] || {
        printf '%s\n' "No active graphical session was found" >&2
        exit 4
    }
    object_path="$(session_object_path "$session_id")"
    [ -n "$object_path" ] || {
        printf '%s\n' "The active logind session could not be resolved" >&2
        exit 4
    }

    busctl call org.freedesktop.login1 "$object_path" \
        org.freedesktop.login1.Session SetBrightness ssu \
        backlight "$device" "$raw" >/dev/null
}

set_external() {
    device="${1:-}"
    percent="$(clamp_percent "${2:-}")" || exit 2
    case "$device" in
        ddc-[0-9]*) bus="${device#ddc-}" ;;
        *) printf '%s\n' "Invalid DDC display" >&2; exit 2 ;;
    esac
    command -v ddcutil >/dev/null 2>&1 || exit 5
    ddcutil --bus "$bus" setvcp 10 "$percent" >/dev/null
}

adjust_internal() {
    delta="${1:-}"
    case "$delta" in
        -[0-9]*|[0-9]*) ;;
        *) exit 2 ;;
    esac
    row="$(brightnessctl -m 2>/dev/null |
        awk -F, '$2 == "backlight" { print $1 "|" $5; exit }')"
    [ -n "$row" ] || exit 3
    device="${row%%|*}"
    percent="${row#*|}"
    percent="${percent%%%}"
    next=$((percent + delta))
    [ "$next" -lt 1 ] && next=1
    [ "$next" -gt 100 ] && next=100
    set_internal "$device" "$next"
}

case "$command_name" in
    snapshot) snapshot_internal ;;
    snapshot-external) snapshot_external ;;
    set-internal) set_internal "${2:-}" "${3:-}" ;;
    adjust-internal) adjust_internal "${2:-}" ;;
    set-external) set_external "${2:-}" "${3:-}" ;;
    *) printf 'Unknown brightness action: %s\n' "$command_name" >&2; exit 2 ;;
esac
