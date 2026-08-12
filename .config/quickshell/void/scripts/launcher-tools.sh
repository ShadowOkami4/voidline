#!/bin/sh

action=${1:-}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

case "$action" in
    capabilities)
        if has_command cliphist && has_command wl-copy && has_command wl-paste; then
            printf 'clipboard|1\n'
        else
            printf 'clipboard|0\n'
        fi
        if has_command wl-copy; then
            printf 'copy|1\n'
        else
            printf 'copy|0\n'
        fi
        if has_command hyprpicker; then
            printf 'color-picker|1\n'
        else
            printf 'color-picker|0\n'
        fi
        if has_command grim && has_command slurp; then
            printf 'screenshot|1\n'
        else
            printf 'screenshot|0\n'
        fi
        if has_command jq; then
            printf 'window-screenshot|1\n'
        else
            printf 'window-screenshot|0\n'
        fi
        ;;
    files)
        needle=${2:-}
        mode=${3:-name}
        location=${4:-home}
        [ "$mode" = name ] || [ "$mode" = content ] || [ "$mode" = recent ] || exit 2
        case "$location" in
            home) search_root=$HOME ;;
            desktop) search_root=$HOME/Desktop ;;
            documents) search_root=$HOME/Documents ;;
            downloads) search_root=$HOME/Downloads ;;
            music) search_root=$HOME/Music ;;
            pictures) search_root=$HOME/Pictures ;;
            videos) search_root=$HOME/Videos ;;
            projects) search_root=$HOME/Projects ;;
            *) exit 2 ;;
        esac
        [ -d "$search_root" ] || search_root=$HOME
        if [ "$mode" = recent ]; then
            # Recent mode scans only the selected location and never the
            # complete filesystem. It is requested explicitly when the file
            # page opens, so there is no idle background indexer.
            find "$search_root" -maxdepth 4 -type f \
                ! -path '*/.cache/*' ! -path '*/.git/*' \
                ! -path '*/node_modules/*' -printf '%T@\t%p\n' 2>/dev/null |
                sort -rn | cut -f2- | head -n 80
            exit 0
        fi
        [ "${#needle}" -ge 2 ] || exit 0
        if [ "$mode" = content ]; then
            rg -l -i --fixed-strings --hidden \
                -g '!.cache/**' \
                -g '!.local/share/Trash/**' \
                -g '!.steam/**' \
                -g '!**/node_modules/**' \
                -g '!**/.git/**' \
                -- "$needle" "$search_root" 2>/dev/null |
                head -n 80
            exit 0
        fi
        cd "$search_root" || exit 1
        rg --files --hidden \
            -g '!.cache/**' \
            -g '!.local/share/Trash/**' \
            -g '!.steam/**' \
            -g '!**/node_modules/**' \
            -g '!**/.git/**' 2>/dev/null |
            awk -v root="$search_root" -v query="$needle" '
                BEGIN { query = tolower(query) }
                {
                    path = tolower($0)
                    name = path
                    sub(/^.*\//, "", name)
                    if (!index(path, query))
                        next
                    score = 3
                    if (name == query)
                        score = 0
                    else if (index(name, query) == 1)
                        score = 1
                    else if (index(name, query))
                        score = 2
                    print score "\t" root "/" $0
                }
            ' |
            sort -t '	' -k1,1n -k2,2 |
            cut -f2- |
            head -n 80
        ;;
    clipboard-list)
        has_command cliphist || exit 127
        cliphist list | head -n 80
        ;;
    clipboard-copy)
        has_command cliphist && has_command wl-copy || exit 127
        printf '%s\n' "${2:-}" | cliphist decode | wl-copy
        ;;
    copy-text)
        has_command wl-copy || exit 127
        printf '%s' "${2:-}" | wl-copy
        ;;
    copy-path)
        has_command wl-copy || exit 127
        target=${2:-}
        case "$target" in "$HOME"|"$HOME"/*) ;; *) exit 2 ;; esac
        [ -e "$target" ] || exit 4
        printf '%s' "$target" | wl-copy
        ;;
    open-containing)
        target=${2:-}
        case "$target" in "$HOME"|"$HOME"/*) ;; *) exit 2 ;; esac
        [ -e "$target" ] || exit 4
        directory=$(dirname -- "$target")
        exec xdg-open "$directory"
        ;;
    color-picker)
        has_command hyprpicker || exit 127
        sleep 0.28
        exec hyprpicker -a
        ;;
    *)
        printf 'Unknown launcher tool action: %s\n' "$action" >&2
        exit 2
        ;;
esac
