#!/bin/sh

set -eu

action="${1:-snapshot}"

schema_available() {
    gsettings list-schemas 2>/dev/null | grep -qx "$1"
}

snapshot() {
    for tool in orca wvkbd-mobintl onboard; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf 'cap|%s|1\n' "$tool"
        else
            printf 'cap|%s|0\n' "$tool"
        fi
    done
    for schema in org.gnome.desktop.a11y.keyboard org.gnome.desktop.a11y.mouse org.gnome.desktop.a11y.applications; do
        if schema_available "$schema"; then
            printf 'schema|%s|1\n' "$schema"
        else
            printf 'schema|%s|0\n' "$schema"
        fi
    done
    if schema_available org.gnome.desktop.a11y.keyboard; then
        printf 'state|sticky|%s\n' "$(gsettings get org.gnome.desktop.a11y.keyboard stickykeys-enable)"
        printf 'state|slow|%s\n' "$(gsettings get org.gnome.desktop.a11y.keyboard slowkeys-enable)"
        printf 'state|bounce|%s\n' "$(gsettings get org.gnome.desktop.a11y.keyboard bouncekeys-enable)"
    fi
    if schema_available org.gnome.desktop.a11y.mouse; then
        printf 'state|clickAssist|%s\n' "$(gsettings get org.gnome.desktop.a11y.mouse secondary-click-enabled)"
        printf 'state|dwell|%s\n' "$(gsettings get org.gnome.desktop.a11y.mouse dwell-click-enabled)"
    fi
    if schema_available org.gnome.desktop.a11y.applications; then
        printf 'state|screenReader|%s\n' "$(gsettings get org.gnome.desktop.a11y.applications screen-reader-enabled)"
        printf 'state|screenKeyboard|%s\n' "$(gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled)"
    fi
}

set_gsetting() {
    key="${1:-}"
    value="${2:-false}"
    case "$key" in
        sticky)
            schema=org.gnome.desktop.a11y.keyboard
            setting=stickykeys-enable ;;
        slow)
            schema=org.gnome.desktop.a11y.keyboard
            setting=slowkeys-enable ;;
        bounce)
            schema=org.gnome.desktop.a11y.keyboard
            setting=bouncekeys-enable ;;
        click-assist)
            schema=org.gnome.desktop.a11y.mouse
            setting=secondary-click-enabled ;;
        dwell)
            schema=org.gnome.desktop.a11y.mouse
            setting=dwell-click-enabled ;;
        screen-reader)
            schema=org.gnome.desktop.a11y.applications
            setting=screen-reader-enabled ;;
        screen-keyboard)
            schema=org.gnome.desktop.a11y.applications
            setting=screen-keyboard-enabled ;;
        *) exit 2 ;;
    esac
    [ "$value" = "true" ] || [ "$value" = "false" ] || exit 2
    schema_available "$schema" || exit 4
    gsettings set "$schema" "$setting" "$value"
}

case "$action" in
    snapshot) snapshot ;;
    set) set_gsetting "${2:-}" "${3:-}" ;;
    launch-keyboard)
        if command -v wvkbd-mobintl >/dev/null 2>&1; then
            exec wvkbd-mobintl
        elif command -v onboard >/dev/null 2>&1; then
            exec onboard
        fi
        exit 4
        ;;
    launch-reader)
        command -v orca >/dev/null 2>&1 || exit 4
        exec orca
        ;;
    *) exit 2 ;;
esac
