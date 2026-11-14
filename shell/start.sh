#!/bin/sh
# Starts (or restarts) the Voidline shell with the UI scale from the config.
# The scale is applied to the whole shell at once, so it has to be set before
# Quickshell starts; the shell re-runs this script when "uiScale" changes.
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/voidline/config.json"
scale=$(awk -F: '/"uiScale"/ { gsub(/[^0-9.]/, "", $2); v = $2 + 0; if (v < 0.5) v = 0.5; if (v > 1.5) v = 1.5; print v; exit }' "$cfg" 2>/dev/null)
[ -n "$scale" ] || scale=0.75

qs kill -c voidline >/dev/null 2>&1 && sleep 0.3
# A shell that is busy or hung does not answer that request, and helpers it
# started can outlive it. Anything still running from an earlier start is
# recognised by the variable set below and stopped, so there is never a second
# bar on screen.
for p in $(pgrep -x quickshell) $(pgrep -x qs) $(pgrep -x dbus-monitor) $(pgrep -x wl-paste); do
    [ "$p" = "$$" ] && continue
    grep -qz '^VOIDLINE_UI_SCALE=' "/proc/$p/environ" 2>/dev/null && kill "$p" 2>/dev/null
done
sleep 0.2

export VOIDLINE_UI_SCALE="$scale"
export QT_SCALE_FACTOR="$scale"
# Quickshell's allocator (jemalloc) keeps a separate pool per CPU core and holds
# on to freed memory. For a shell that is all cost: one pool, returned at once,
# roughly halves memory use on a many-core machine with no measurable CPU cost.
export MALLOC_CONF="${MALLOC_CONF:-narenas:1,dirty_decay_ms:0,muzzy_decay_ms:0}"
exec qs -c voidline
