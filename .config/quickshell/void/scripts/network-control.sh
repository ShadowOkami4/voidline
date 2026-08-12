#!/bin/sh
set -eu

export LC_ALL=C

runtime_root=${XDG_RUNTIME_DIR:-}
[ -n "$runtime_root" ] || exit 70
[ -d "$runtime_root" ] || exit 70

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
iwd_connect_helper="$script_dir/iwd-connect.py"

state_dir="$runtime_root/voidline"
state_file="$state_dir/network-state"
lock_file="$state_dir/network-operation.lock"
mkdir -p -m 700 "$state_dir"
: >"$lock_file"
chmod 600 "$lock_file"

clean_field() {
    printf '%s' "$1" | tr '|\t\r\n' '¦   '
}

backend() {
    if command -v nmcli >/dev/null 2>&1 \
            && systemctl is-active --quiet NetworkManager 2>/dev/null; then
        printf '%s\n' networkmanager
    elif command -v iwctl >/dev/null 2>&1 \
            && systemctl is-active --quiet iwd 2>/dev/null; then
        printf '%s\n' iwd
    else
        printf '%s\n' missing
    fi
}

write_state() {
    state=$1
    ssid=${2:-}
    error_code=${3:-}
    detail=${4:-}
    temp_file=$(mktemp "$state_dir/network-state.XXXXXX")
    chmod 600 "$temp_file"
    {
        printf 'state|%s\n' "$(clean_field "$state")"
        printf 'ssid|%s\n' "$(clean_field "$ssid")"
        printf 'error|%s\n' "$(clean_field "$error_code")"
        printf 'detail|%s\n' "$(clean_field "$detail")"
        printf 'backend|%s\n' "$(backend)"
        printf 'updated|%s\n' "$(date +%s)"
    } > "$temp_file"
    mv -f "$temp_file" "$state_file"
}

run_locked() {
    exec 9>"$lock_file"
    if ! flock -n 9; then
        write_state busy "${2:-}" busy "Another network operation is already running"
        exit 75
    fi
    "$@"
}

normalise_error() {
    log_file=$1
    if grep -Eqi 'passphrase|password|credential|authentication|not authorized|secrets were required' "$log_file"; then
        printf '%s\n' authentication
    elif grep -Eqi 'not found|no network|invalid network name|not available' "$log_file"; then
        printf '%s\n' unavailable
    elif grep -Eqi 'timeout|timed out' "$log_file"; then
        printf '%s\n' timeout
    elif grep -Eqi '8021x|enterprise|eap' "$log_file"; then
        printf '%s\n' enterprise
    else
        printf '%s\n' connection
    fi
}

current_connection() {
    interface_name=$(iw dev 2>/dev/null | awk '$1 == "Interface" { print $2; exit }')
    [ -n "$interface_name" ] || return 0
    "$script_dir/wifi-snapshot.sh" "$interface_name" 2>/dev/null |
        awk -F '|' '$1 == "network" && $5 == 1 { print $2; exit }'
}

reconcile_state() {
    connected_ssid=$(current_connection)
    current_state=
    current_ssid=
    current_backend=
    if [ -r "$state_file" ]; then
        current_state=$(awk -F '|' '$1 == "state" { print $2; exit }' "$state_file")
        current_ssid=$(awk -F '|' '$1 == "ssid" { print $2; exit }' "$state_file")
        current_backend=$(awk -F '|' '$1 == "backend" { print $2; exit }' "$state_file")
    fi
    if [ -n "$connected_ssid" ]; then
        if [ "$current_state" != connected ] \
                || [ "$current_ssid" != "$connected_ssid" ] \
                || [ "$current_backend" != "$(backend)" ]; then
            write_state connected "$connected_ssid"
        fi
    elif [ "$current_state" != disconnected ] \
            || [ -n "$current_ssid" ] \
            || [ "$current_backend" != "$(backend)" ]; then
        write_state disconnected ""
    fi
}

nm_saved_uuid() {
    wanted_ssid=$1
    nmcli -g UUID connection show 2>/dev/null | while IFS= read -r uuid; do
        [ -n "$uuid" ] || continue
        type=$(nmcli -g connection.type connection show uuid "$uuid" 2>/dev/null || true)
        [ "$type" = 802-11-wireless ] || [ "$type" = wifi ] || continue
        profile_ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null || true)
        if [ "$profile_ssid" = "$wanted_ssid" ]; then
            printf '%s\n' "$uuid"
            break
        fi
    done
}

do_scan() {
    interface_name=$1
    write_state scanning ""
    log_file=$(mktemp "$state_dir/network-scan.XXXXXX")
    chmod 600 "$log_file"
    trap 'rm -f -- "$log_file"' EXIT HUP INT TERM

    result=0

    case "$(backend)" in
        networkmanager)
            nmcli device wifi rescan ifname "$interface_name" \
                >"$log_file" 2>&1 || result=$?
            ;;
        iwd)
            iwctl station "$interface_name" scan \
                >"$log_file" 2>&1 || result=$?
            ;;
        *)
            write_state failed "" backend "No supported network backend is active"
            exit 69
            ;;
    esac

    connected_ssid=$(current_connection)
    if [ "$result" -eq 0 ]; then
        if [ -n "$connected_ssid" ]; then
            write_state connected "$connected_ssid"
        else
            write_state idle ""
        fi
        return 0
    fi

    if grep -Eqi 'not authorized|permission denied|not permitted' "$log_file"; then
        error_code=permission
    else
        error_code=$(normalise_error "$log_file")
    fi
    error_detail=$(tail -n 1 "$log_file" 2>/dev/null || true)
    if [ -n "$connected_ssid" ]; then
        write_state connected "$connected_ssid" "$error_code" "$error_detail"
    else
        write_state failed "" "$error_code" "$error_detail"
    fi
    return "$result"
}

do_connect() {
    interface_name=$1
    ssid=$2
    security=$3
    hidden=$4
    known=$5
    IFS= read -r passphrase || passphrase=

    case "$interface_name" in *[!A-Za-z0-9_.:-]*|'') exit 64 ;; esac
    [ -n "$ssid" ] || exit 64
    case "$security" in open|psk|8021x|'') ;; *) exit 64 ;; esac
    case "$hidden:$known" in 0:0|0:1|1:0|1:1) ;; *) exit 64 ;; esac

    write_state connecting "$ssid"
    log_file=$(mktemp "$state_dir/network-connect.XXXXXX")
    chmod 600 "$log_file"
    trap 'passphrase=; rm -f -- "$log_file"' EXIT HUP INT TERM

    result=0
    case "$(backend)" in
        networkmanager)
            # NetworkManager credentials must never pass through nmcli. The
            # shared QML service invokes the installed libnm worker directly.
            # Keep this legacy entry point closed instead of silently falling
            # back to a less secure activation path.
            result=69
            printf 'NetworkManager activation requires voidline-network\n' >"$log_file"
            ;;
        iwd)
            if [ "$security" = 8021x ]; then
                result=11
                printf 'Enterprise EAP profiles require an iwd provisioning profile\n' >"$log_file"
            elif [ ! -r "$iwd_connect_helper" ]; then
                result=12
                printf 'Voidline iwd credential helper is missing\n' >"$log_file"
            else
                printf '%s\n' "$passphrase" \
                    | /usr/bin/python3 "$iwd_connect_helper" \
                        "$interface_name" "$ssid" "$security" "$hidden" "$known" \
                        >"$log_file" 2>&1 || result=$?
            fi
            ;;
        *)
            result=12
            printf 'No supported network backend is active\n' >"$log_file"
            ;;
    esac

    passphrase=
    if [ "$result" -eq 0 ]; then
        write_state connected "$ssid"
        exit 0
    fi

    error_code=$(normalise_error "$log_file")
    error_detail=$(tail -n 1 "$log_file" 2>/dev/null || true)
    write_state failed "$ssid" "$error_code" "$error_detail"
    exit "$result"
}

do_disconnect() {
    interface_name=$1
    ssid=${2:-}
    write_state disconnecting "$ssid"
    log_file=$(mktemp "$state_dir/network-disconnect.XXXXXX")
    chmod 600 "$log_file"
    trap 'rm -f -- "$log_file"' EXIT HUP INT TERM
    result=0
    case "$(backend)" in
        networkmanager) nmcli --wait 10 device disconnect "$interface_name" >"$log_file" 2>&1 || result=$? ;;
        iwd) iwctl station "$interface_name" disconnect >"$log_file" 2>&1 || result=$? ;;
        *) result=12; printf 'No supported network backend is active\n' >"$log_file" ;;
    esac
    if [ "$result" -eq 0 ]; then
        write_state disconnected "$ssid"
    else
        write_state failed "$ssid" disconnect "$(tail -n 1 "$log_file" 2>/dev/null || true)"
    fi
    exit "$result"
}

do_forget() {
    ssid=$1
    write_state forgetting "$ssid"
    log_file=$(mktemp "$state_dir/network-forget.XXXXXX")
    chmod 600 "$log_file"
    trap 'rm -f -- "$log_file"' EXIT HUP INT TERM
    result=0
    case "$(backend)" in
        networkmanager)
            uuid=$(nm_saved_uuid "$ssid")
            if [ -n "$uuid" ]; then
                nmcli connection delete uuid "$uuid" >"$log_file" 2>&1 || result=$?
            else
                result=10
                printf 'Saved profile was not found\n' >"$log_file"
            fi
            ;;
        iwd) iwctl known-networks "$ssid" forget >"$log_file" 2>&1 || result=$? ;;
        *) result=12; printf 'No supported network backend is active\n' >"$log_file" ;;
    esac
    if [ "$result" -eq 0 ]; then
        write_state idle "$ssid"
    else
        write_state failed "$ssid" forget "$(tail -n 1 "$log_file" 2>/dev/null || true)"
    fi
    exit "$result"
}

case "${1:-}" in
    backend) backend ;;
    state)
        # Do not let an old failed attempt override the adapter's actual state.
        # The non-blocking lock keeps this reconciliation out of active flows.
        exec 8>"$lock_file"
        if flock -n 8; then
            reconcile_state
        fi
        if [ -r "$state_file" ]; then
            cat "$state_file"
        else
            write_state idle ""
            cat "$state_file"
        fi
        ;;
    scan)
        shift
        run_locked do_scan "$@"
        ;;
    connect)
        shift
        run_locked do_connect "$@"
        ;;
    disconnect)
        shift
        run_locked do_disconnect "$@"
        ;;
    forget)
        shift
        run_locked do_forget "$@"
        ;;
    *) exit 64 ;;
esac
