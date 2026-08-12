#!/bin/sh

ap_interface="$(iw dev 2>/dev/null | awk '
    $1 == "Interface" { interface = $2 }
    $1 == "type" && $2 == "AP" { print interface; exit }
')"

if [ -z "$ap_interface" ]; then
    exit 0
fi

iw dev "$ap_interface" station dump 2>/dev/null | awk '
    $1 == "Station" { printf "client|%s\n", $2 }
'
