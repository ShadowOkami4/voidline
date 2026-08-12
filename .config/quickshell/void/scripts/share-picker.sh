#!/bin/sh
set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
shell_directory=$(CDPATH= cd -- "$script_directory/.." && pwd)

safe_result_file() {
    result=${VOIDLINE_PICKER_RESULT:-}
    runtime=${XDG_RUNTIME_DIR:-/tmp}
    case "$result" in
        "$runtime"/voidline-share-picker-result.*.txt) ;;
        *) return 1 ;;
    esac
    [ ! -d "$result" ] || return 1
    printf '%s\n' "$result"
}

write_selection() {
    selection=$1
    result=$(safe_result_file) || exit 3
    temporary=$(mktemp "${result}.XXXXXX")
    trap 'rm -f "$temporary"' EXIT HUP INT TERM
    printf '%s\n' "$selection" >"$temporary"
    chmod 0600 "$temporary"
    mv -f -- "$temporary" "$result"
    trap - EXIT HUP INT TERM
}

remember_prefix() {
    if [ "${1:-0}" = "1" ]; then
        printf 'r'
    fi
}

valid_output_name() {
    case "$1" in
        ""|*[!A-Za-z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}

valid_integer() {
    printf '%s\n' "$1" | grep -Eq '^-?[0-9]+$'
}

snapshot() {
    printf 'meta\t%s\n' "${VOIDLINE_PICKER_ALLOW_TOKEN:-0}"
    [ -n "${XDPH_WINDOW_SHARING_LIST:-}" ] || return 0

    # XDPH supplies entries as:
    # handle[HC>]class[HT>]title[HE>]address[HA>]
    # Convert only its reserved separators to a compact TSV stream. The
    # portal-provided numeric handle is kept unchanged for window selection.
    printf '%s' "$XDPH_WINDOW_SHARING_LIST" |
        sed \
            -e 's/\[HC>\]/	/g' \
            -e 's/\[HT>\]/	/g' \
            -e 's/\[HE>\]/	/g' \
            -e 's/\[HA>\]/\
/g' |
        while IFS='	' read -r handle class title address; do
            case "$handle" in
                ""|*[!0-9]*) continue ;;
            esac
            clean_class=$(printf '%s' "$class" | tr '\t\r\n' '   ')
            clean_title=$(printf '%s' "$title" | tr '\t\r\n' '   ')
            printf 'window\t%s\t%s\t%s\n' \
                "$handle" "$clean_class" "$clean_title"
        done
}

select_item() {
    type=${2:-}
    payload=${3:-}
    remember=${4:-0}
    prefix=$(remember_prefix "$remember")

    case "$type" in
        screen)
            valid_output_name "$payload" || exit 2
            write_selection "[SELECTION]${prefix}/screen:${payload}"
            ;;
        window)
            case "$payload" in
                ""|*[!0-9]*) exit 2 ;;
            esac
            write_selection "[SELECTION]${prefix}/window:${payload}"
            ;;
        *)
            exit 2
            ;;
    esac
}

select_region() {
    remember=${1:-0}
    accent="#8FB8AC"
    settings_file=$shell_directory/settings.json
    if [ -r "$settings_file" ] && command -v jq >/dev/null 2>&1; then
        candidate=$(jq -r '.accentColor // empty' "$settings_file" 2>/dev/null || true)
        if printf '%s\n' "$candidate" | grep -Eq '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$'; then
            accent=$(printf '%.7s' "$candidate")
        fi
    fi

    region=$(slurp -b '#141218CC' -c "${accent}FF" -s "${accent}4D" \
        -w 3 -f '%o %x %y %w %h') || exit 1
    set -- $region
    [ "$#" -eq 5 ] || exit 2

    output=$1
    x=$2
    y=$3
    width=$4
    height=$5
    valid_output_name "$output" || exit 2
    valid_integer "$x" || exit 2
    valid_integer "$y" || exit 2
    valid_integer "$width" || exit 2
    valid_integer "$height" || exit 2
    [ "$width" -gt 0 ] && [ "$height" -gt 0 ] || exit 2

    origin=$(hyprctl monitors -j |
        jq -r --arg output "$output" \
            '.[] | select(.name == $output) | "\(.x) \(.y)"' |
        sed -n '1p')
    [ -n "$origin" ] || exit 2
    set -- $origin
    origin_x=$1
    origin_y=$2
    valid_integer "$origin_x" || exit 2
    valid_integer "$origin_y" || exit 2

    local_x=$((x - origin_x))
    local_y=$((y - origin_y))
    prefix=$(remember_prefix "$remember")
    write_selection \
        "[SELECTION]${prefix}/region:${output}@${local_x},${local_y},${width},${height}"
}

case "${1:-}" in
    snapshot) snapshot ;;
    select) select_item "$@" ;;
    region) select_region "${2:-0}" ;;
    *) exit 2 ;;
esac
