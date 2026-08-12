#!/bin/sh

wifi_interface="$(iw dev 2>/dev/null | awk '
    $1 == "Interface" { interface = $2 }
    $1 == "type" && $2 == "managed" { print interface; exit }
')"
internet_interface="$(ip -4 route show default 2>/dev/null | awk '$1 == "default" { print $5; exit }')"

printf 'wifi|%s\n' "$wifi_interface"
printf 'internet|%s\n' "$internet_interface"
