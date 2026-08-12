#!/bin/sh
set -eu

shell_dir=${1:-"$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"}

printf '%s\n' '== Always-running timers =='
rg -n -U 'Timer[[:space:]]*\{[^}]{0,260}(running:[[:space:]]*true|repeat:[[:space:]]*true)' \
    "$shell_dir" --glob '*.qml' || true

printf '\n%s\n' '== Detached processes and command construction =='
rg -n 'execDetached|command:[[:space:]]*\[|/bin/(sh|bash).*-[[:space:]]*c|eval[[:space:]]' \
    "$shell_dir" --glob '*.qml' --glob '*.sh' || true

printf '\n%s\n' '== Temporary files and broad permissions =='
rg -n '/tmp/|mktemp|chmod[[:space:]]+(666|777)|umask[[:space:]]+0' \
    "$shell_dir" --glob '*.qml' --glob '*.sh' || true

printf '\n%s\n' '== Incomplete implementation markers =='
rg -n 'TODO|FIXME|placeholder|not implemented|planned for a later build' \
    "$shell_dir" --glob '*.qml' --glob '*.js' --glob '*.sh' || true
