#!/bin/sh

read -r _ void_cpu_user void_cpu_nice void_cpu_system void_cpu_idle void_cpu_iowait void_cpu_irq void_cpu_softirq void_cpu_steal _ _ < /proc/stat
void_cpu_idle_all=$((void_cpu_idle + void_cpu_iowait))
void_cpu_total=$((void_cpu_user + void_cpu_nice + void_cpu_system + void_cpu_idle + void_cpu_iowait + void_cpu_irq + void_cpu_softirq + void_cpu_steal))
printf 'cpu %s %s\n' "$void_cpu_idle_all" "$void_cpu_total"

awk '
    /^MemTotal:/ { total=$2 }
    /^MemAvailable:/ { available=$2 }
    /^SwapTotal:/ { swap_total=$2 }
    /^SwapFree:/ { swap_free=$2 }
    END {
        printf "memory %d %d\n", total, available
        printf "swap %d %d\n", swap_total, swap_free
    }
' /proc/meminfo

awk '{ printf "load %s\n", $1 }' /proc/loadavg

void_cpu_temp=$(sensors -u k10temp-pci-00c3 2>/dev/null | awk '/temp1_input:/ { print $2; exit }')
printf 'temperature %s\n' "${void_cpu_temp:-0}"

void_cycles=$(cat /sys/class/power_supply/BAT0/cycle_count 2>/dev/null)
void_energy_full=$(cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null)
void_energy_design=$(cat /sys/class/power_supply/BAT0/energy_full_design 2>/dev/null)
printf 'battery %s %s %s\n' "${void_cycles:-0}" "${void_energy_full:-0}" "${void_energy_design:-0}"

df -Pk / | awk 'NR == 2 { printf "disk %d %d\n", $3, $2 }'

void_uptime=$(awk '{ printf "%.0f", $1 }' /proc/uptime)
void_processes=0
for void_process in /proc/[0-9]*; do
    [ -d "$void_process" ] && void_processes=$((void_processes + 1))
done

void_frequency=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
printf 'system %s %s %s\n' "${void_frequency:-0}" "$void_processes" "${void_uptime:-0}"

void_gpu_usage=0
for void_gpu_path in /sys/class/drm/card*/device/gpu_busy_percent; do
    if [ -r "$void_gpu_path" ]; then
        read -r void_gpu_usage < "$void_gpu_path"
        break
    fi
done
printf 'gpu %s\n' "${void_gpu_usage:-0}"

void_gpu_temp=0
for void_gpu_temp_path in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
    if [ -r "$void_gpu_temp_path" ]; then
        read -r void_gpu_temp < "$void_gpu_temp_path"
        void_gpu_temp=$((void_gpu_temp / 1000))
        break
    fi
done

void_vram_used=0
void_vram_total=0
for void_vram_path in /sys/class/drm/card*/device/mem_info_vram_used; do
    if [ -r "$void_vram_path" ]; then
        read -r void_vram_used < "$void_vram_path"
        void_vram_total_path=${void_vram_path%_used}_total
        [ -r "$void_vram_total_path" ] && read -r void_vram_total < "$void_vram_total_path"
        break
    fi
done
printf 'gpu_detail %s %s %s\n' "$void_gpu_temp" "$void_vram_used" "$void_vram_total"

void_network_interface=$(awk '$2 == "00000000" && $1 != "Iface" { print $1; exit }' /proc/net/route)
if [ -n "$void_network_interface" ] && [ -r "/sys/class/net/$void_network_interface/statistics/rx_bytes" ]; then
    read -r void_network_rx < "/sys/class/net/$void_network_interface/statistics/rx_bytes"
    read -r void_network_tx < "/sys/class/net/$void_network_interface/statistics/tx_bytes"
    printf 'network %s %s %s\n' "$void_network_interface" "$void_network_rx" "$void_network_tx"
fi

awk '
    $3 ~ /^(nvme[0-9]+n[0-9]+|sd[a-z]+|vd[a-z]+|mmcblk[0-9]+)$/ {
        read_sectors += $6
        written_sectors += $10
    }
    END { printf "diskio %.0f %.0f\n", read_sectors, written_sectors }
' /proc/diskstats

# Aggregate helper processes into applications before selecting the top five.
# This keeps multi-process applications such as browsers and Discord from
# occupying every row of the compact resource view.
ps -eo comm=,pcpu=,pmem= 2>/dev/null \
    | awk 'NF >= 3 { cpu[$1]+=$2; memory[$1]+=$3 }
        END { for (name in cpu) printf "%s|%.1f|%.1f\n", name, cpu[name], memory[name] }' \
    | sort -t '|' -k2,2nr \
    | awk -F '|' 'count < 5 { printf "topcpu|%s|%s|%s\n", $1, $2, $3; count++ }'
ps -eo comm=,pcpu=,pmem= 2>/dev/null \
    | awk 'NF >= 3 { cpu[$1]+=$2; memory[$1]+=$3 }
        END { for (name in cpu) printf "%s|%.1f|%.1f\n", name, cpu[name], memory[name] }' \
    | sort -t '|' -k3,3nr \
    | awk -F '|' 'count < 5 { printf "topmem|%s|%s|%s\n", $1, $2, $3; count++ }'
