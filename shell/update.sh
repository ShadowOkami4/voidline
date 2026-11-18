#!/bin/sh
# Updates Voidline from the git folder it was installed from, then installs
# it again (install.sh restarts the shell). Started from Settings > About.
here=$(cd "$(dirname "$0")" && pwd)
src=$(cat "$here/source.txt" 2>/dev/null)
log=${XDG_CACHE_HOME:-$HOME/.cache}/voidline/update.log
mkdir -p "$(dirname "$log")"
fail() {
    notify-send -a Voidline -i voidline-settings "Voidline could not be updated" "$1  (details: $log)"
    exit 1
}
{
    echo "== $(date)"
    [ -n "$src" ] && [ -d "$src/.git" ] || fail "The folder it was installed from is gone."
    cd "$src" || exit 1
    git pull --ff-only || fail "git could not take the new version."
    ./install.sh || fail "The installer stopped with an error."
} >> "$log" 2>&1 || exit 1
notify-send -a Voidline -i voidline-settings "Voidline updated" "Now at $(git -C "$src" log -1 --format=%h)."
