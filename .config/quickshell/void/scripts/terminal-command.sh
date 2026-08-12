#!/bin/sh

command_text=$1

if [ -z "$command_text" ]; then
    exit 2
fi

run_in_terminal() {
    terminal_name=$1

    case "$terminal_name" in
        xdg-terminal-exec)
            exec xdg-terminal-exec sh -lc "$command_text"
            ;;
        ghostty)
            exec ghostty -e sh -lc "$command_text"
            ;;
        kitty)
            exec kitty -- sh -lc "$command_text"
            ;;
        foot|footclient)
            exec "$terminal_name" sh -lc "$command_text"
            ;;
        alacritty)
            exec alacritty -e sh -lc "$command_text"
            ;;
        wezterm)
            exec wezterm start -- sh -lc "$command_text"
            ;;
        konsole)
            exec konsole -e sh -lc "$command_text"
            ;;
        gnome-terminal)
            exec gnome-terminal -- sh -lc "$command_text"
            ;;
        xterm)
            exec xterm -e sh -lc "$command_text"
            ;;
    esac
}

if [ -n "${TERMINAL:-}" ]; then
    preferred_terminal=${TERMINAL%% *}
    preferred_terminal=${preferred_terminal##*/}
    if command -v "$preferred_terminal" >/dev/null 2>&1; then
        run_in_terminal "$preferred_terminal"
    fi
fi

for terminal_name in xdg-terminal-exec ghostty kitty footclient foot alacritty wezterm konsole gnome-terminal xterm; do
    if command -v "$terminal_name" >/dev/null 2>&1; then
        run_in_terminal "$terminal_name"
    fi
done

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Voidline Shell" "No terminal emulator was found"
fi
exit 127
