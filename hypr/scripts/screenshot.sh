#!/usr/bin/env bash

# Screenshot utility for Hyprland with dunst / notify-send notifications

# Resolve pictures directory
if [ -n "$XDG_PICTURES_DIR" ] && [ -d "$XDG_PICTURES_DIR" ]; then
    SCREENSHOT_DIR="$XDG_PICTURES_DIR/Screenshots"
elif [ -d "$HOME/Bilder" ]; then
    SCREENSHOT_DIR="$HOME/Bilder/Screenshots"
else
    SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
fi

mkdir -p "$SCREENSHOT_DIR"

MODE="${1:-area}"
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
FILENAME="Screenshot_${TIMESTAMP}.png"
FILEPATH="${SCREENSHOT_DIR}/${FILENAME}"

notify_screenshot() {
    notify-send -a "Screenshot" \
        -i "$FILEPATH" \
        -t 3000 \
        -h string:x-dunst-stack-tag:screenshot \
        "Screenshot Captured" \
        "Saved to $(basename "$FILEPATH") & copied to clipboard"
}

case "$MODE" in
    screen|fullscreen|output)
        grim "$FILEPATH" || exit 1
        ;;
    window)
        # Get active window geometry from hyprctl
        GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)
        if [ -n "$GEOM" ] && [ "$GEOM" != "null,null nullxnull" ]; then
            grim -g "$GEOM" "$FILEPATH" || exit 1
        else
            grim "$FILEPATH" || exit 1
        fi
        ;;
    area|region|select|*)
        GEOM=$(slurp -d -b 00000080 -c 89b4fa -w 2 2>/dev/null)
        # User canceled selection (e.g. pressed Escape or clicked outside)
        if [ -z "$GEOM" ]; then
            exit 0
        fi
        sleep 0.1
        grim -g "$GEOM" "$FILEPATH" || exit 1
        ;;
esac

if [ -f "$FILEPATH" ]; then
    wl-copy -t image/png < "$FILEPATH"
    notify_screenshot
fi
