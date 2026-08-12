#!/bin/sh
set -eu

location=${1:-}
[ -n "$location" ] || exit 64

control=$(command -v voidlinectl 2>/dev/null || true)
if [ -z "$control" ]; then
    control=${XDG_BIN_HOME:-${HOME:?}/.local/bin}/voidlinectl
fi
[ -x "$control" ] || exit 69

exec "$control" --json --yes online weather "$location"
