#!/bin/sh
set -eu

# The model never supplies a shell command. This bridge accepts only the
# explicit operations below and validates every path before opening it.

case "${1:-}" in
    resolve-home-item)
        query=${2:-}
        [ -n "$query" ] || exit 2
        result=$(find "$HOME" -xdev -mindepth 1 -maxdepth 7 \
            \( -path "$HOME/.cache" -o -path "$HOME/.local/share/Trash" \
                -o -path "$HOME/.git" -o -path '*/node_modules' \) -prune \
            -o \( -type d -o \( -type f ! -name '*.desktop' ! -perm /111 \) \) \
            -iname "*$query*" -print -quit 2>/dev/null || true)
        [ -n "$result" ] || exit 1
        realpath -e -- "$result"
        ;;
    reveal-path)
        requested=${2:-}
        [ -n "$requested" ] || exit 2
        canonical=$(realpath -e -- "$requested") || exit 1
        case "$canonical" in
            "$HOME"/*) ;;
            *) printf '%s\n' "Path is outside the user home directory" >&2; exit 3 ;;
        esac
        if command -v nautilus >/dev/null 2>&1; then
            exec nautilus --select "$canonical"
        fi
        if [ -d "$canonical" ]; then
            exec xdg-open "$canonical"
        fi
        exec xdg-open "$(dirname "$canonical")"
        ;;
    *)
        exit 2
        ;;
esac
