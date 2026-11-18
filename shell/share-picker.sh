#!/bin/sh
# Asked by the Hyprland portal (xdg-desktop-portal-hyprland) whenever an app
# wants to share the screen: a call, a recorder, a browser tab. It hands the
# question to the Voidline shell, waits for your choice in its dialog and
# prints it the way the portal expects:
#   [SELECTION]/screen:eDP-1     [SELECTION]/window:1234     [SELECTION]r/region:eDP-1@0,0,800,600
# Nothing printed means "cancelled". Set up in ~/.config/hypr/xdph.conf:
#   screencopy { custom_picker_binary = ~/.config/quickshell/voidline/share-picker.sh }
answer="${XDG_RUNTIME_DIR:-/tmp}/voidline-share-$$"
rm -f "$answer"

if ! qs -c voidline ipc call shell sharePick "$answer" "${XDPH_WINDOW_SHARING_LIST:--}" >/dev/null 2>&1; then
    # The shell is not running: the portal's own picker still works.
    command -v hyprland-share-picker >/dev/null && exec hyprland-share-picker
    exit 1
fi

# Up to two minutes to decide.
i=0
while [ ! -f "$answer" ] && [ "$i" -lt 1200 ]; do sleep 0.1; i=$((i + 1)); done
if [ -s "$answer" ]; then cat "$answer"; rm -f "$answer"; exit 0; fi
rm -f "$answer"
qs -c voidline ipc call shell shareChoose "" >/dev/null 2>&1
exit 1
