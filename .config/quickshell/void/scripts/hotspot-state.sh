#!/bin/sh

if ! command -v create_ap >/dev/null 2>&1; then
    printf '%s\n' '0'
    exit 0
fi

# `create_ap --list-running` requires root even for a read, while process
# command lines are readable to the desktop user on a normal Arch session.
if pgrep -f '^(/bin/bash|bash) /usr/bin/create_ap([[:space:]]|$)' >/dev/null 2>&1; then
    printf '%s\n' '1'
else
    printf '%s\n' '0'
fi
