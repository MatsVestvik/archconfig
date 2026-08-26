#!/usr/bin/env bash

THEME="$HOME/.config/rofi/widget-menu.rasi"

lock="   Lock"
sleep="󰤄   Sleep"
logout="󰍃   Log Off"
reboot="󰑐   Reboot"
shutdown="󰐥   Turn Off"
cancel="   Cancel"

OPTIONS="$lock\n$sleep\n$logout\n$reboot\n$shutdown\n$cancel"

CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -theme "$THEME" -p "⏻ Power Menu" -mesg "System Actions ($USER @ $(hostname))")

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    *"Lock"*)
        if command -v hyprlock >/dev/null 2>&1; then
            hyprlock &
        elif command -v i3lock >/dev/null 2>&1; then
            i3lock &
        else
            loginctl lock-session
        fi
        ;;
    *"Sleep"*)
        systemctl suspend
        ;;
    *"Log Off"*)
        if [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
            hyprctl dispatch exit
        elif [ -n "$I3SOCK" ]; then
            i3-msg exit
        else
            loginctl terminate-session self
        fi
        ;;
    *"Reboot"*)
        systemctl reboot
        ;;
    *"Turn Off"*)
        systemctl poweroff
        ;;
    *"Cancel"*)
        exit 0
        ;;
esac
