#!/bin/sh

format_bytes() {
    bytes=${1:-0}
    awk -v value="$bytes" 'BEGIN {
        if (value >= 1073741824) printf "%.1f GiB", value / 1073741824
        else if (value >= 1048576) printf "%.1f MiB", value / 1048576
        else if (value >= 1024) printf "%.1f KiB", value / 1024
        else printf "%d B", value
    }'
}

case "${1:-snapshot}" in
    snapshot)
        os_name=$(
            . /etc/os-release 2>/dev/null
            printf '%s' "${PRETTY_NAME:-Arch Linux}"
        )
        hostname_value=$(hostname 2>/dev/null || sed -n '1p' /etc/hostname 2>/dev/null)
        kernel_value=$(uname -r 2>/dev/null || printf unknown)
        case "$kernel_value" in
            *-zen*) kernel_type=linux-zen ;;
            *-lts*) kernel_type=linux-lts ;;
            *-hardened*) kernel_type=linux-hardened ;;
            *) kernel_type=linux ;;
        esac
        uptime_value=$(uptime -p 2>/dev/null | sed 's/^up //' || true)
        quickshell_value=$(qs --version 2>/dev/null | head -n 1 || printf unavailable)
        hyprland_value=$(hyprctl version 2>/dev/null | head -n 1 || printf unavailable)
        cpu_value=$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo 2>/dev/null | head -n 1)
        if command -v lspci >/dev/null 2>&1; then
            gpu_value=$(lspci 2>/dev/null |
                sed -n '/VGA compatible controller\|3D controller\|Display controller/{s/^[^:]*: //;p;}' |
                paste -sd ',' -)
        else
            gpu_value=Unavailable
        fi
        memory_bytes=$(awk '/^MemTotal:/ { print $2 * 1024 }' /proc/meminfo 2>/dev/null)
        storage_values=$(df -B1 --output=size,used / 2>/dev/null | awk 'NR == 2 { print $1 " " $2 }')
        storage_total=${storage_values%% *}
        storage_used=${storage_values#* }
        usb_count=$(find /sys/bus/usb/devices -maxdepth 1 -type l -name '*-*' 2>/dev/null | wc -l)
        if command -v lpstat >/dev/null 2>&1; then
            printer_count=$(lpstat -p 2>/dev/null | wc -l)
            printer_backend=ready
        else
            printer_count=0
            printer_backend=missing
        fi

        active_interface=$(ip route show default 2>/dev/null | awk 'NR == 1 { print $5 }')
        rx_bytes=0
        tx_bytes=0
        if [ -n "$active_interface" ] && [ -r "/sys/class/net/$active_interface/statistics/rx_bytes" ]; then
            rx_bytes=$(sed -n '1p' "/sys/class/net/$active_interface/statistics/rx_bytes")
            tx_bytes=$(sed -n '1p' "/sys/class/net/$active_interface/statistics/tx_bytes")
        fi

        printf 'os|%s\n' "$os_name"
        printf 'hostname|%s\n' "$hostname_value"
        printf 'kernel|%s\n' "$kernel_value"
        printf 'kerneltype|%s\n' "${kernel_type:-Linux}"
        printf 'uptime|%s\n' "${uptime_value:-Unknown}"
        printf 'quickshell|%s\n' "$quickshell_value"
        printf 'hyprland|%s\n' "$hyprland_value"
        printf 'windowmanager|Hyprland\n'
        printf 'desktopshell|Voidline on Quickshell\n'
        printf 'cpu|%s\n' "${cpu_value:-Unavailable}"
        printf 'gpu|%s\n' "${gpu_value:-Unavailable}"
        printf 'memory|%s\n' "$(format_bytes "${memory_bytes:-0}")"
        printf 'storage|%s|%s\n' "$(format_bytes "${storage_total:-0}")" \
            "$(format_bytes "${storage_used:-0}")"
        printf 'usb|%s\n' "$usb_count"
        printf 'printers|%s|%s\n' "$printer_count" "$printer_backend"
        printf 'traffic|%s|%s|%s\n' "${active_interface:-none}" \
            "$(format_bytes "$rx_bytes")" "$(format_bytes "$tx_bytes")"
        ;;
    updates)
        if command -v checkupdates >/dev/null 2>&1; then
            update_list=$(checkupdates 2>/dev/null || true)
            if [ -n "$update_list" ]; then
                printf 'updates|%s\n' "$(printf '%s\n' "$update_list" | wc -l)"
            else
                printf 'updates|0\n'
            fi
        else
            printf 'updates|missing\n'
        fi
        ;;
    *)
        exit 2
        ;;
esac
