#!/bin/sh

set -eu

action="${1:-snapshot}"

require_tools() {
    command -v pactl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1
}

snapshot() {
    require_tools || {
        printf '%s\n' '{"cards":[],"sinks":[],"sources":[],"error":"pactl or jq is unavailable"}'
        exit 0
    }
    cards="$(pactl -f json list cards)"
    sinks="$(pactl -f json list sinks)"
    sources="$(pactl -f json list sources)"
    jq -cn --argjson cards "$cards" --argjson sinks "$sinks" \
        --argjson sources "$sources" \
        '{cards:$cards,sinks:$sinks,sources:$sources}'
}

set_profile() {
    card="${1:-}"
    profile="${2:-}"
    [ -n "$card" ] && [ -n "$profile" ] || exit 2
    pactl -f json list cards |
        jq -e --arg card "$card" --arg profile "$profile" '
            any(.[]; .name == $card and
                (((.profiles // []) | if type == "array" then . else to_entries | map(.value + {name:.key}) end)
                    | any(.[]; .name == $profile and (.available // "yes") != "no")))
        ' >/dev/null
    pactl set-card-profile "$card" "$profile"
}

set_port() {
    kind="${1:-}"
    node="${2:-}"
    port="${3:-}"
    [ "$kind" = "sink" ] || [ "$kind" = "source" ] || exit 2
    [ -n "$node" ] && [ -n "$port" ] || exit 2
    plural="${kind}s"
    pactl -f json list "$plural" |
        jq -e --arg node "$node" --arg port "$port" '
            any(.[]; .name == $node and
                (((.ports // []) | if type == "array" then . else to_entries | map(.value + {name:.key}) end)
                    | any(.[]; .name == $port and (.availability // .available // "yes") != "not available")))
        ' >/dev/null
    pactl "set-${kind}-port" "$node" "$port"
}

case "$action" in
    snapshot) snapshot ;;
    set-profile) set_profile "${2:-}" "${3:-}" ;;
    set-port) set_port "${2:-}" "${3:-}" "${4:-}" ;;
    *) exit 2 ;;
esac
