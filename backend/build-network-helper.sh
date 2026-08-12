#!/bin/sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v cc >/dev/null 2>&1 || {
    printf '%s\n' 'A C compiler is required to build the libnm network helper.' >&2
    exit 69
}
pkg-config --exists libnm gio-unix-2.0 || {
    printf '%s\n' 'libnm and gio-unix development files are required.' >&2
    exit 69
}
install -d -m 755 "$workspace/target/release"
cc -std=c17 -D_POSIX_C_SOURCE=200809L -O2 -fstack-protector-strong \
    -D_FORTIFY_SOURCE=3 -Wall -Wextra -Werror -Wno-deprecated-declarations \
    $(pkg-config --cflags libnm gio-unix-2.0) \
    "$workspace/native/voidline-network.c" \
    -Wl,-z,relro,-z,now \
    $(pkg-config --libs libnm gio-unix-2.0) \
    -o "$workspace/target/release/voidline-network"
