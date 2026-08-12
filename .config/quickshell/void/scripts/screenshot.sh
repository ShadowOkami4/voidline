#!/bin/sh

set -eu

mode=${1:-region}
output=${2:-}
launch_context=${3:-panel}
pictures_dir=$(xdg-user-dir PICTURES 2>/dev/null || true)
[ -n "$pictures_dir" ] || pictures_dir="$HOME/Pictures"
screenshot_dir="$pictures_dir/Screenshots"
mkdir -p "$screenshot_dir"
path="$screenshot_dir/$(date '+%Y-%m-%d_%H-%M-%S').png"

# Launcher actions need to let the panel close before pixels are sampled.
# Keyboard shortcuts do not have a panel to conceal and can capture immediately.
if [ "$launch_context" = "panel" ]; then
    sleep 0.34
fi

case "$mode" in
    screen)
        if [ -z "$output" ] && command -v jq >/dev/null 2>&1; then
            output=$(hyprctl -j monitors 2>/dev/null \
                | jq -r '.[] | select(.focused == true) | .name' \
                | head -n 1)
        fi
        if [ -n "$output" ]; then
            grim -o "$output" "$path"
        else
            grim "$path"
        fi
        ;;
    window)
        if ! command -v jq >/dev/null 2>&1; then
            notify-send 'Screenshot unavailable' 'Install jq for active-window capture'
            exit 127
        fi
        geometry=$(hyprctl -j activewindow | jq -er '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$geometry" "$path"
        ;;
    region)
        geometry=$(slurp) || exit 0
        [ -n "$geometry" ] || exit 0
        grim -g "$geometry" "$path"
        ;;
    *)
        exit 2
        ;;
esac

if command -v wl-copy >/dev/null 2>&1; then
    wl-copy --type image/png < "$path"
    notify-send 'Screenshot captured' "Saved and copied to clipboard\n$path"
else
    notify-send 'Screenshot captured' "Saved to $path"
fi
