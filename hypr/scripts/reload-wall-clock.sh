#!/usr/bin/env sh

set -eu

pkill waybar || true
pkill hyprpaper || true
pkill -f wall-clock.sh || true

sleep 0.5

waybar >/dev/null 2>&1 &
hyprpaper >/dev/null 2>&1 &
kitty --class wallpaper-clock --title wallpaper-clock --override background_opacity=0 --override font_size=46 -e /home/mats/.config/hypr/scripts/wall-clock.sh >/dev/null 2>&1 &