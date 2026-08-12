#!/bin/sh
set -eu

# Adapter from Lyra's provider-independent tool names to the versioned
# voidlinectl protocol. Arguments are never evaluated as shell code.
action=${1:-}
approved=${2:-0}
first=${3:-}
second=${4:-}
third=${5:-}

control=$(command -v voidlinectl 2>/dev/null || true)
if [ -z "$control" ]; then
    user_control=${XDG_BIN_HOME:-${HOME:?}/.local/bin}/voidlinectl
    [ -x "$user_control" ] && control=$user_control
fi
[ -n "$control" ] && [ -x "$control" ] || exit 69

run_protected() {
    if [ "$approved" = 1 ]; then
        exec "$control" --yes "$@"
    else
        exec "$control" "$@"
    fi
}

case "$action" in
    search_apps)
        exec "$control" --json search "$first" --kind applications
        ;;
    search_games)
        exec "$control" --json search "$first" --kind games
        ;;
    search_files)
        kind=files
        [ "$second" = content ] && kind=file-contents
        exec "$control" --json search "$first" --kind "$kind" --location "$third"
        ;;
    online_search)
        if [ "$approved" = 1 ]; then
            exec "$control" --json --yes online search "$first"
        fi
        exec "$control" --json online search "$first"
        ;;
    online_weather)
        if [ "$approved" = 1 ]; then
            exec "$control" --json --yes online weather "$first"
        fi
        exec "$control" --json online weather "$first"
        ;;
    open_panel)
        exec "$control" --json panel open "$first"
        ;;
    open_settings)
        exec "$control" --json settings open "$first"
        ;;
    set_volume)
        exec "$control" --json volume "$first"
        ;;
    set_brightness)
        exec "$control" --json brightness "$first"
        ;;
    set_dnd)
        exec "$control" --json dnd "$first"
        ;;
    set_wifi)
        run_protected --json wifi "$first"
        ;;
    set_bluetooth)
        run_protected --json bluetooth "$first"
        ;;
    power_profile)
        exec "$control" --json power-mode "$first"
        ;;
    screenshot)
        run_protected --json screenshot region
        ;;
    color_picker)
        exec "$control" --json color-picker
        ;;
    keep_awake)
        exec "$control" --json keep-awake
        ;;
    screen_record)
        run_protected --json record toggle
        ;;
    lock)
        exec "$control" --json lock
        ;;
    session)
        run_protected --json session "$first"
        ;;
    *)
        exit 64
        ;;
esac
