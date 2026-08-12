#!/bin/sh

# Narrow command bridge for the Settings application. Every writable setting
# is explicitly allow-listed so text entered in the UI is never evaluated as
# shell code.

export LC_ALL=C

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

clean_field() {
    printf '%s' "$1" | tr '|\t\r\n' '    '
}

printer_name_from_uri() {
    printf '%s\n' "$1" |
        sed \
            -e 's|^[A-Za-z0-9+.-]*://||' \
            -e 's|/.*$||' \
            -e 's|\._[^.]*\._tcp.*$||' \
            -e 's/%20/ /g' \
            -e 's/%2[Dd]/-/g' \
            -e 's/%5[Ff]/_/g'
}

scanner_is_camera() {
    scanner_id=$1
    scanner_name=$2
    case "$scanner_id" in
        v4l:*|video:*|test:*) return 0 ;;
    esac
    normalized=$(printf '%s %s\n' "$scanner_id" "$scanner_name" |
        tr '[:upper:]' '[:lower:]')
    case "$normalized" in
        *camera*|*webcam*|*infrared*|*"video4linux"*|*"video device"*) return 0 ;;
        *) return 1 ;;
    esac
}

emit_capability() {
    if command_exists "$2"; then
        printf 'cap|%s|1\n' "$1"
    else
        printf 'cap|%s|0\n' "$1"
    fi
}

config_file=${VOIDLINE_HYPR_CONFIG:-"$HOME/.config/hypr/config.lua"}
monitor_file=${VOIDLINE_MONITOR_CONFIG:-"$HOME/.config/hypr/monitors.lua"}

emit_config_setting() {
    variable=$1
    [ -r "$config_file" ] || return
    value=$(sed -n "s/^[[:space:]]*$variable[[:space:]]*=[[:space:]]*//p" "$config_file" |
        head -n 1 | sed 's/[[:space:]]*--.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
    [ -n "$value" ] && printf 'setting|%s|%s\n' "$variable" "$value"
}

snapshot() {
    include_devices=${1:-1}
    emit_capability cups lpstat
    emit_capability scanners scanimage
    emit_capability airscan airscan-discover
    emit_capability mdns avahi-browse
    if command_exists avahi-browse \
            && systemctl is-active --quiet avahi-daemon.service 2>/dev/null; then
        printf 'cap|mdns-active|1\n'
    else
        printf 'cap|mdns-active|0\n'
    fi
    emit_capability cameras v4l2-ctl
    emit_capability bluetooth bluetoothctl
    emit_capability color colormgr
    emit_capability nightlight hyprsunset
    emit_capability networkmanager nmcli
    emit_capability wireguard wg
    emit_capability brightness brightnessctl
    emit_capability pipewire wpctl
    emit_capability audio pw-dump
    emit_capability imagemagick magick
    emit_capability pci lspci

    for variable in \
        BorderSize Activecolor Inactivecolor Active_opacity Inactive_opacity \
        Rounding WindowGaps ScreenGaps Shadow_enabled Shadow_range \
        Shadow_render_power Shadow_scale Shadow_color Blur_enabled Blur_size \
        Blur_passes Blur_popups PointerSensitivity NaturalScroll TapToClick \
        ScrollMethod KeyboardLayout RepeatRate RepeatDelay WorkspaceSwipe \
        Animation; do
        emit_config_setting "$variable"
    done

    if command_exists hyprctl && command_exists jq; then
        monitors_json=$(hyprctl -j monitors 2>/dev/null || true)
        if printf '%s' "$monitors_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
            printf '%s' "$monitors_json" | jq -r '
            .[] | [
                "monitor", .name, (.description // .name),
                (.width|tostring), (.height|tostring),
                (.refreshRate|tostring), (.x|tostring), (.y|tostring),
                (.scale|tostring), (.transform|tostring),
                (.focused|tostring), (.disabled|tostring),
                ((.vrr // false)|tostring), (.mirrorOf // ""),
                (.currentFormat // ""), (.colorManagementPreset // "srgb"),
                ((.availableModes // [])|join(","))
            ] | join("|")'
        fi

        devices_json=$(hyprctl -j devices 2>/dev/null || true)
        if printf '%s' "$devices_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
            printf '%s' "$devices_json" | jq -r '
            ((.mice // [])[] |
                (.name // "Pointer") as $name |
                ["input",
                    (if ($name | ascii_downcase | test("touchpad|trackpad"))
                        then "touchpad" else "mouse" end),
                    $name] | join("|")),
            ((.keyboards // [])[] |
                ["input","keyboard",.name,(.active_keymap // "")] | join("|")),
            ((.tablets // [])[] |
                ["input","tablet",(.name // "Tablet")] | join("|")),
            ((.touch // [])[] |
                ["input","touchscreen",(.name // "Touchscreen")] | join("|"))'
        fi
    fi

    if [ "$include_devices" = 1 ] && command_exists bluetoothctl; then
        bluetoothctl devices 2>/dev/null | while read -r marker address device_name; do
            [ "$marker" = Device ] || continue
            information=$(bluetoothctl info "$address" 2>/dev/null)
            paired=$(printf '%s\n' "$information" | sed -n 's/^[[:space:]]*Paired: //p')
            connected=$(printf '%s\n' "$information" | sed -n 's/^[[:space:]]*Connected: //p')
            battery=$(printf '%s\n' "$information" | sed -n 's/^[[:space:]]*Percentage:.*(\([0-9]*\)).*/\1%/p')
            alias=$(printf '%s\n' "$information" | sed -n 's/^[[:space:]]*Alias: //p')
            status=Discovered
            [ "$paired" = yes ] && status=Paired
            [ "$connected" = yes ] && status=Connected
            printf 'device|bluetooth|%s|%s|%s|Bluetooth||%s|BlueZ|%s\n' \
                "$address" "${alias:-$device_name}" "$status" "${alias:-$device_name}" "$battery"
        done
    fi

    if [ "$include_devices" = 1 ] && command_exists lpstat; then
        lpstat -p 2>/dev/null | while read -r marker printer_name rest; do
            [ "$marker" = printer ] || continue
            printer_uri=$(lpstat -v "$printer_name" 2>/dev/null |
                sed -n 's/^device for [^:]*: //p')
            safe_name=$(clean_field "$printer_name")
            safe_uri=$(clean_field "${printer_uri:-Local or network}")
            printf 'device|printer|%s|%s|Saved|%s||%s|CUPS|\n' \
                "$safe_name" "$safe_name" "$safe_uri" "$safe_name"
        done
    fi
    if [ "$include_devices" = 1 ] && command_exists lpinfo; then
        timeout 8 lpinfo -v 2>/dev/null | while read -r class printer_uri; do
            case "$printer_uri" in
                dnssd://*|ipp://*|ipps://*|lpd://*|socket://*|usb://*) ;;
                *) continue ;;
            esac
            printer_name=$(printer_name_from_uri "$printer_uri")
            [ -n "$printer_name" ] || printer_name="Available printer"
            manufacturer=
            case "$(printf '%s' "$printer_name" | tr '[:upper:]' '[:lower:]')" in
                *epson*) manufacturer=Epson ;;
            esac
            safe_uri=$(clean_field "$printer_uri")
            safe_name=$(clean_field "$printer_name")
            printf 'device|printer|%s|%s|Available|%s|%s|%s|CUPS driverless|\n' \
                "$safe_uri" "$safe_name" "$safe_uri" "$manufacturer" "$safe_name"
        done
    fi

    if [ "$include_devices" = 1 ] && command_exists scanimage; then
        timeout 8 scanimage -L 2>/dev/null | while IFS= read -r scanner_line; do
            scanner_id=$(printf '%s\n' "$scanner_line" |
                sed -n "s/^device \`\\([^']*\\)'.*/\\1/p")
            scanner_name=$(printf '%s\n' "$scanner_line" |
                sed -n "s/^device .* is a \\(.*\\)$/\\1/p")
            [ -n "$scanner_id" ] || continue
            scanner_is_camera "$scanner_id" "$scanner_name" && continue

            scanner_backend=${scanner_id%%:*}
            scanner_connection="Local scanner"
            case "$scanner_id" in
                airscan:*|escl:*|wsd:*|*network*) scanner_connection="Network scanner" ;;
            esac
            scanner_manufacturer=
            case "$(printf '%s' "$scanner_name" | tr '[:upper:]' '[:lower:]')" in
                *epson*) scanner_manufacturer=Epson ;;
            esac
            safe_id=$(clean_field "$scanner_id")
            safe_name=$(clean_field "${scanner_name:-Scanner}")
            printf 'device|scanner|%s|%s|Available|%s|%s|%s|%s|\n' \
                "$safe_id" "$safe_name" "$scanner_connection" \
                "$scanner_manufacturer" "$safe_name" "$scanner_backend"
        done
    fi

    if [ "$include_devices" = 1 ] && command_exists v4l2-ctl; then
        v4l2-ctl --list-devices 2>/dev/null |
            sed -n '/:$/s/[[:space:]]*:$//p' | while IFS= read -r camera_name; do
                printf 'device|camera|%s|%s|Connected|Video4Linux||%s|v4l2|\n' \
                    "$camera_name" "$camera_name" "$camera_name"
            done
    fi

    if [ "$include_devices" = 1 ] && command_exists lsusb; then
        lsusb 2>/dev/null | while read -r bus bus_number device_word device_number id_word usb_id usb_name; do
            [ "$id_word" = ID ] || continue
            printf 'device|usb|%s|%s|Connected|USB|%s|%s|usbcore|\n' \
                "$usb_id" "${usb_name:-USB device}" "${usb_name%% *}" "${usb_name:-USB device}"
        done
    fi

    if [ "$include_devices" = 1 ] && command_exists lsblk && command_exists jq; then
        lsblk -J -o NAME,LABEL,SIZE,TYPE,RM,MOUNTPOINTS,VENDOR,MODEL,SERIAL 2>/dev/null | jq -r '
            .blockdevices[] | .. | objects |
            select(.type == "disk" or .type == "part") |
            ["device","storage",("/dev/" + .name),(.label // .model // .name),
             (if ((.mountpoints // []) | map(select(. != null)) | length) > 0
                then "Mounted" elif .rm then "Removable" else "Connected" end),.size,
             (.vendor // ""),(.model // .name),
             (if .type == "part" then "block-partition" else "block-disk" end),
             (.serial // "")] | join("|")'
    fi

    if [ "$include_devices" = 1 ] && command_exists pw-dump \
            && command_exists jq; then
        pw-dump 2>/dev/null | jq -r '
            .[] |
            select(.type == "PipeWire:Interface:Node") |
            (.info.props // {}) as $properties |
            select(($properties["media.class"] // "")
                | test("^Audio/(Sink|Source)$")) |
            ["device", "audio",
                (($properties["object.serial"] // .id // "audio") | tostring),
                ($properties["node.description"]
                    // $properties["node.nick"]
                    // $properties["node.name"] // "Audio device"),
                "Available",
                ("PipeWire · " + (($properties["media.class"] // "Audio")
                    | sub("Audio/"; ""))),
                ($properties["device.vendor.name"] // ""),
                ($properties["device.product.name"]
                    // $properties["node.description"] // ""),
                "PipeWire", ""] | join("|")'
    fi

    if [ "$include_devices" = 1 ] && [ -d /dev/input/by-id ]; then
        find /dev/input/by-id -maxdepth 1 -type l \
            \( -name '*joystick*' -o -name '*gamepad*' \) -printf '%f\n' 2>/dev/null |
            while IFS= read -r controller; do
                printf 'device|controller|%s|%s|Connected|Linux input||%s|evdev|\n' \
                    "$controller" "$controller" "$controller"
            done
    fi

    if command_exists resolvectl; then
        dns_value=$(resolvectl dns 2>/dev/null | head -n 1 | sed 's/^[^:]*:[[:space:]]*//')
        printf 'network|dns|%s\n' "${dns_value:-Automatic}"
    fi
}

discover_devices() {
    case "$1" in
        bluetooth)
            command_exists bluetoothctl || exit 4
            bluetoothctl --timeout 6 scan on >/dev/null 2>&1
            ;;
        printer|scanner|printscan)
            discovered=0
            if [ "$1" != scanner ] && command_exists lpinfo; then
                timeout 8 lpinfo -v >/dev/null 2>&1 || true
                discovered=1
            fi
            if [ "$1" != printer ] && command_exists scanimage; then
                timeout 8 scanimage -L >/dev/null 2>&1 || true
                discovered=1
            fi
            [ "$discovered" -eq 1 ] || exit 4
            ;;
        camera)
            command_exists v4l2-ctl || exit 4
            v4l2-ctl --list-devices >/dev/null 2>&1
            ;;
        usb|storage|audio|controller|tablet|touchscreen|mouse|touchpad|keyboard)
            ;;
        *) exit 2 ;;
    esac
}

device_action() {
    kind=$1
    action=$2
    identifier=$3

    case "$kind:$action" in
        bluetooth:pair|bluetooth:connect|bluetooth:disconnect|bluetooth:remove)
            case "$identifier" in
                [0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]) ;;
                *) exit 2 ;;
            esac
            exec bluetoothctl "$action" "$identifier"
            ;;
        printer:test)
            case "$identifier" in *[!A-Za-z0-9_.-]*|'') exit 2 ;; esac
            test_page=/usr/share/cups/data/testprint
            [ -r "$test_page" ] || exit 4
            exec lp -d "$identifier" "$test_page"
            ;;
        printer:add)
            case "$identifier" in
                dnssd://*|ipp://*|ipps://*|lpd://*|socket://*|usb://*) ;;
                *) exit 2 ;;
            esac
            command_exists lpadmin || exit 4
            queue_name=$(printer_name_from_uri "$identifier" |
                tr -cs 'A-Za-z0-9_.-' '_' | cut -c 1-48)
            queue_name=${queue_name#_}
            queue_name=${queue_name%_}
            [ -n "$queue_name" ] || queue_name=VoidlinePrinter
            if command_exists pkexec; then
                exec pkexec lpadmin -p "$queue_name" -E \
                    -v "$identifier" -m everywhere
            fi
            exec lpadmin -p "$queue_name" -E -v "$identifier" -m everywhere
            ;;
        printer:remove)
            case "$identifier" in *[!A-Za-z0-9_.-]*|'') exit 2 ;; esac
            command_exists lpadmin || exit 4
            if command_exists pkexec; then
                exec pkexec lpadmin -x "$identifier"
            fi
            exec lpadmin -x "$identifier"
            ;;
        scanner:probe)
            [ -n "$identifier" ] || exit 2
            command_exists scanimage || exit 4
            exec scanimage -d "$identifier" -A
            ;;
        storage:mount|storage:unmount)
            case "$identifier" in /dev/[A-Za-z0-9._-]*) ;; *) exit 2 ;; esac
            command_exists udisksctl || exit 4
            exec udisksctl "$action" -b "$identifier"
            ;;
        *) exit 2 ;;
    esac
}

write_config_setting() {
    variable=$1
    literal=$2
    directory=$(dirname "$config_file")
    [ -d "$directory" ] || exit 3
    [ -f "$config_file" ] || : > "$config_file"

    temporary=$(mktemp "$directory/.voidline-config.XXXXXX") || exit 3
    if ! awk -v variable="$variable" -v literal="$literal" '
        BEGIN { replaced = 0 }
        {
            trimmed = $0
            sub(/^[[:space:]]*/, "", trimmed)
            if (!replaced && index(trimmed, variable) == 1) {
                rest = substr(trimmed, length(variable) + 1)
                if (rest ~ /^[[:space:]]*=/) {
                    print variable " = " literal " -- Managed by Voidline Settings"
                    replaced = 1
                    next
                }
            }
            print
        }
        END {
            if (!replaced)
                print variable " = " literal " -- Managed by Voidline Settings"
        }
    ' "$config_file" > "$temporary"; then
        rm -f "$temporary"
        exit 3
    fi
    chmod --reference="$config_file" "$temporary" 2>/dev/null || chmod 600 "$temporary"
    mv "$temporary" "$config_file"
}

apply_hypr() {
    key=$1
    value=$2

    variable=
    literal=
    hypr_value=$value
    case "$key" in
        general:border_size|general:gaps_in|general:gaps_out|\
        decoration:rounding|decoration:shadow:range|\
        decoration:shadow:render_power|decoration:blur:size|\
        decoration:blur:passes|input:repeat_rate|input:repeat_delay)
            case "$value" in *[!0-9]*|'') exit 2 ;; esac
            ;;
        decoration:active_opacity|decoration:inactive_opacity|\
        decoration:shadow:scale|input:sensitivity)
            case "$value" in *[!0-9.-]*|'') exit 2 ;; esac
            ;;
        decoration:blur:enabled|decoration:blur:popups|\
        decoration:shadow:enabled|input:touchpad:natural_scroll|\
        input:touchpad:tap-to-click)
            case "$value" in 0|1|true|false) ;; *) exit 2 ;; esac
            ;;
        general:col.active_border)
            case "$value" in
                *'|'*)
                    first=${value%%|*}
                    remainder=${value#*|}
                    second=${remainder%%|*}
                    angle=${remainder#*|}
                    [ "$remainder" != "$value" ] && [ "$angle" != "$remainder" ] || exit 2
                    case "$first" in 'rgb('*')'|'rgba('*')') ;; *) exit 2 ;; esac
                    case "$second" in 'rgb('*')'|'rgba('*')') ;; *) exit 2 ;; esac
                    case "$angle" in *[!0-9]*|'') exit 2 ;; esac
                    [ "$angle" -le 360 ] || exit 2
                    variable=Activecolor
                    literal="{ colors = { \"$first\", \"$second\" }, angle = $angle }"
                    hypr_value="$first $second ${angle}deg"
                    ;;
                'rgb('*')'|'rgba('*')') ;;
                *) exit 2 ;;
            esac
            ;;
        general:col.inactive_border|decoration:shadow:color)
            case "$value" in 'rgb('*')'|'rgba('*')') ;; *) exit 2 ;; esac
            ;;
        input:kb_layout)
            case "$value" in *[!A-Za-z0-9,_-]*|'') exit 2 ;; esac
            ;;
        input:scroll_method)
            case "$value" in 2fg|edge|on_button_down) ;; *) exit 2 ;; esac
            ;;
        gestures:workspace_swipe)
            case "$value" in 0|1|true|false) ;; *) exit 2 ;; esac
            ;;
        *)
            exit 2
            ;;
    esac

    case "$key" in
        general:border_size) variable=BorderSize; literal=$value ;;
        general:gaps_in) variable=WindowGaps; literal=$value ;;
        general:gaps_out) variable=ScreenGaps; literal=$value ;;
        general:col.active_border)
            variable=${variable:-Activecolor}
            [ -n "$literal" ] || literal="\"$value\""
            ;;
        general:col.inactive_border) variable=Inactivecolor; literal="\"$value\"" ;;
        decoration:rounding) variable=Rounding; literal=$value ;;
        decoration:active_opacity) variable=Active_opacity; literal=$value ;;
        decoration:inactive_opacity) variable=Inactive_opacity; literal=$value ;;
        decoration:shadow:enabled) variable=Shadow_enabled; literal=$value ;;
        decoration:shadow:range) variable=Shadow_range; literal=$value ;;
        decoration:shadow:render_power) variable=Shadow_render_power; literal=$value ;;
        decoration:shadow:scale) variable=Shadow_scale; literal=$value ;;
        decoration:shadow:color) variable=Shadow_color; literal="\"$value\"" ;;
        decoration:blur:enabled) variable=Blur_enabled; literal=$value ;;
        decoration:blur:size) variable=Blur_size; literal=$value ;;
        decoration:blur:passes) variable=Blur_passes; literal=$value ;;
        decoration:blur:popups) variable=Blur_popups; literal=$value ;;
        input:sensitivity) variable=PointerSensitivity; literal=$value ;;
        input:touchpad:natural_scroll) variable=NaturalScroll; literal=$value ;;
        input:touchpad:tap-to-click) variable=TapToClick; literal=$value ;;
        input:scroll_method) variable=ScrollMethod; literal="\"$value\"" ;;
        input:kb_layout) variable=KeyboardLayout; literal="\"$value\"" ;;
        input:repeat_rate) variable=RepeatRate; literal=$value ;;
        input:repeat_delay) variable=RepeatDelay; literal=$value ;;
        gestures:workspace_swipe) variable=WorkspaceSwipe; literal=$value ;;
    esac

    config_backup=$(mktemp "$(dirname "$config_file")/.voidline-config-backup.XXXXXX") || exit 3
    if [ -f "$config_file" ]; then
        cp -p -- "$config_file" "$config_backup" || {
            rm -f -- "$config_backup"
            exit 3
        }
    else
        : >"$config_backup"
    fi

    write_config_setting "$variable" "$literal"
    if ! hyprctl keyword "$key" "$hypr_value" >/dev/null; then
        mv -- "$config_backup" "$config_file"
        exit 5
    fi
    rm -f -- "$config_backup"

    # Confirm the compositor accepted the value. The persisted config was
    # already written atomically; a full compositor reload is unnecessary.
    if command_exists jq; then
        confirmed=$(hyprctl getoption -j "$key" 2>/dev/null |
            jq -r '.int // .float // .str // .custom // empty' 2>/dev/null || true)
        [ -n "$confirmed" ] || exit 6
        printf 'confirmed|%s|%s\n' "$key" "$confirmed"
    else
        printf 'confirmed|%s|%s\n' "$key" "$value"
    fi
}

apply_monitor() {
    name=$1
    mode=$2
    position=$3
    scale=$4
    transform=$5
    vrr=$6
    mirror=$7
    color_profile=${8:-srgb}

    case "$name" in *[!A-Za-z0-9_.:-]*|'') exit 2 ;; esac
    if [ "$mode" = disabled ]; then
        write_monitor_setting "$name" disabled 0x0 1 0 0 none srgb false
        hyprctl keyword monitor "$name,disable" >/dev/null
        printf 'confirmed|monitor|%s\n' "$name"
        return
    fi

    case "$mode" in *[!A-Za-z0-9x@._-]*|'') exit 2 ;; esac
    case "$position" in *[!0-9x-]*|'') exit 2 ;; esac
    case "$scale" in *[!0-9.]*|'') exit 2 ;; esac
    case "$transform" in 0|1|2|3|4|5|6|7) ;; *) exit 2 ;; esac
    case "$vrr" in 0|1|2|3) ;; *) exit 2 ;; esac
    case "$color_profile" in srgb|dcip3|dp3|adobe|wide|edid|hdr|hdredid) ;; *) exit 2 ;; esac

    arguments="$name,$mode,$position,$scale,transform,$transform,vrr,$vrr,cm,$color_profile"
    case "$color_profile" in hdr|hdredid)
        arguments="$arguments,bitdepth,10"
        ;;
    esac
    if [ -n "$mirror" ] && [ "$mirror" != none ]; then
        case "$mirror" in *[!A-Za-z0-9_.:-]*) exit 2 ;; esac
        arguments="$arguments,mirror,$mirror"
    fi
    write_monitor_setting "$name" "$mode" "$position" "$scale" "$transform" \
        "$vrr" "${mirror:-none}" "$color_profile" true
    hyprctl keyword monitor "$arguments" >/dev/null
    printf 'confirmed|monitor|%s\n' "$name"
}

safe_monitors() {
    command_exists hyprctl || exit 4
    command_exists jq || exit 4
    names=$(hyprctl -j monitors all 2>/dev/null | jq -r '.[].name')
    [ -n "$names" ] || exit 4
    printf '%s\n' "$names" | while IFS= read -r name; do
        case "$name" in *[!A-Za-z0-9_.:-]*|'') continue ;; esac
        hyprctl keyword monitor "$name,preferred,auto,1" >/dev/null || true
        write_monitor_setting "$name" preferred auto 1 0 0 none srgb true
    done
}

write_monitor_setting() {
    name=$1
    mode=$2
    position=$3
    scale=$4
    transform=$5
    vrr=$6
    mirror=$7
    color_profile=$8
    enabled=$9

    directory=$(dirname "$monitor_file")
    [ -d "$directory" ] || exit 3
    if [ ! -f "$monitor_file" ]; then
        printf '%s\n' 'return {' '}' > "$monitor_file"
    fi
    row="    [\"$name\"] = { output = \"$name\", mode = \"$mode\", position = \"$position\", scale = $scale, transform = $transform, vrr = $vrr, mirror = \"$mirror\", color_profile = \"$color_profile\", enabled = $enabled },"
    temporary=$(mktemp "$directory/.voidline-monitors.XXXXXX") || exit 3
    if ! awk -v name="$name" -v row="$row" '
        BEGIN { replaced = 0; inserted = 0 }
        {
            if (index($0, "[\"" name "\"]") > 0) {
                print row
                replaced = 1
                next
            }
            if (!replaced && !inserted && $0 ~ /^}[[:space:]]*$/) {
                print row
                inserted = 1
            }
            print
        }
    ' "$monitor_file" > "$temporary"; then
        rm -f "$temporary"
        exit 3
    fi
    chmod --reference="$monitor_file" "$temporary" 2>/dev/null || chmod 600 "$temporary"
    mv "$temporary" "$monitor_file"
}

animation_preset() {
    case "$1" in
        off) animation=disabled ;;
        calm) animation=smooth ;;
        balanced) animation=fast ;;
        expressive) animation=dynamic ;;
        *) exit 2 ;;
    esac
    write_config_setting Animation "\"$animation\""
    hyprctl reload
}

apply_appearance() {
    kind=$1
    name=$2
    case "$name" in *[!A-Za-z0-9_.+-]*|'') exit 2 ;; esac

    case "$kind" in
        cursor)
            exec hyprctl setcursor "$name" 24
            ;;
        icons)
            if command_exists gsettings; then
                exec gsettings set org.gnome.desktop.interface icon-theme "$name"
            fi
            exit 1
            ;;
        *) exit 2 ;;
    esac
}

case "${1:-snapshot}" in
    snapshot|snapshot-devices) snapshot 1 ;;
    snapshot-core) snapshot 0 ;;
    hypr) shift; apply_hypr "$@" ;;
    monitor) shift; apply_monitor "$@" ;;
    safe-monitors) safe_monitors ;;
    animation) animation_preset "${2:-balanced}" ;;
    appearance) shift; apply_appearance "$@" ;;
    discover) discover_devices "${2:-}" ;;
    device-action) shift; device_action "$@" ;;
    test-sound)
        for sample in \
            /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga \
            /usr/share/sounds/freedesktop/stereo/message.oga; do
            if [ -r "$sample" ]; then
                exec pw-play "$sample"
            fi
        done
        exit 1
        ;;
    *) exit 2 ;;
esac
