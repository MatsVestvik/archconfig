#!/usr/bin/env bash

# If rofi is already open, toggle it closed
if pgrep -x rofi >/dev/null 2>&1; then
    killall rofi
    exit 0
fi

# Stream results into rofi. Do NOT use --follow to prevent circular
# symlink traversal (e.g. Proton/Wine z: -> /) escaping $HOME.
if command -v fd >/dev/null 2>&1; then
    chosen=$(fd . "$HOME" \
        --hidden \
        --threads 2 \
        --exclude .git \
        --exclude node_modules \
        --exclude .cache \
        --exclude '.local/share/Steam' \
        --exclude '.local/share/Trash' \
        --exclude .wine \
        --exclude .var \
        --exclude .cargo \
        --exclude .rustup \
        2>/dev/null | rofi -dmenu -p "Search..." -i)
else
    chosen=$(find "$HOME" -mindepth 1 \
        \( -path "*/.git/*" \
        -o -path "*/node_modules/*" \
        -o -path "*/.cache/*" \
        -o -path "*/.local/share/Steam/*" \
        -o -path "*/.local/share/Trash/*" \
        -o -path "*/.wine/*" \
        -o -path "*/.var/*" \
        -o -path "*/.cargo/*" \
        -o -path "*/.rustup/*" \) -prune \
        -o -print 2>/dev/null | rofi -dmenu -p "Search..." -i)
fi

if [ -n "$chosen" ]; then
    if [ -d "$chosen" ]; then
        code "$chosen"
    else
        xdg-open "$chosen"
    fi
fi
