#!/usr/bin/env bash

THEME="$HOME/.config/rofi/widget-menu.rasi"

# Get controller status
BT_SHOW=$(bluetoothctl show 2>/dev/null)
BT_POWERED=$(echo "$BT_SHOW" | grep -q "Powered: yes" && echo "yes" || echo "no")
BT_DISCOV=$(echo "$BT_SHOW" | grep -q "Discoverable: yes" && echo "yes" || echo "no")
BT_NAME=$(echo "$BT_SHOW" | grep "Alias:" | head -n1 | cut -d: -f2- | xargs)

# Get connected and paired devices
CONNECTED_DEVS=()
PAIRED_DEVS=()

if [ "$BT_POWERED" = "yes" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        mac=$(echo "$line" | awk '{print $2}')
        name=$(echo "$line" | cut -d' ' -f3-)
        
        info=$(bluetoothctl info "$mac" 2>/dev/null)
        if echo "$info" | grep -q "Connected: yes"; then
            battery=$(echo "$info" | grep "Battery Percentage:" | awk '{print $3}' | tr -d '()')
            if [ -n "$battery" ]; then
                CONNECTED_DEVS+=("$mac|$name ($battery%)")
            else
                CONNECTED_DEVS+=("$mac|$name")
            fi
        else
            PAIRED_DEVS+=("$mac|$name")
        fi
    done < <(bluetoothctl devices Paired 2>/dev/null)
fi

# Build Status Message
if [ "$BT_POWERED" != "yes" ]; then
    STATUS_MSG="Bluetooth is turned off"
elif [ ${#CONNECTED_DEVS[@]} -gt 0 ]; then
    names=""
    for dev in "${CONNECTED_DEVS[@]}"; do
        dname=$(echo "$dev" | cut -d'|' -f2)
        names="${names}${names:+, }$dname"
    done
    STATUS_MSG="Connected to: $names"
else
    STATUS_MSG="Bluetooth on (${BT_NAME:-Endeavour}) | No devices connected"
fi

# Build options list
OPTIONS=""

# 1. Power & Discoverable toggle
if [ "$BT_POWERED" = "yes" ]; then
    OPTIONS+="󰂯  Turn Bluetooth Off\n"
    if [ "$BT_DISCOV" = "yes" ]; then
        OPTIONS+="󰂰  Make Undiscoverable\n"
    else
        OPTIONS+="󰂰  Make Discoverable (3 min)\n"
    fi
    OPTIONS+="󰑐  Scan for Nearby Devices\n"
else
    OPTIONS+="󰂲  Turn Bluetooth On\n"
fi

# 2. Recommended Managers
OPTIONS+="󰒓  Open Bluetooth Manager (Blueman GUI)\n"
OPTIONS+="💻  Open Bluetooth Terminal (bluetoothctl)\n"

# 3. Connected devices
for dev in "${CONNECTED_DEVS[@]}"; do
    mac=$(echo "$dev" | cut -d'|' -f1)
    name=$(echo "$dev" | cut -d'|' -f2)
    OPTIONS+="󰂱  Disconnect: $name [$mac]\n"
done

# 4. Paired devices (not currently connected)
for dev in "${PAIRED_DEVS[@]}"; do
    mac=$(echo "$dev" | cut -d'|' -f1)
    name=$(echo "$dev" | cut -d'|' -f2)
    OPTIONS+="󰂯  Connect: $name [$mac]\n"
done

# Show rofi menu
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -theme "$THEME" -p "󰂯 Bluetooth" -mesg "$STATUS_MSG")

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    *"Turn Bluetooth Off"*)
        bluetoothctl power off
        notify-send -u low -i bluetooth-disabled "Bluetooth" "Bluetooth powered off"
        ;;
    *"Turn Bluetooth On"*)
        bluetoothctl power on
        notify-send -u low -i bluetooth-active "Bluetooth" "Bluetooth powered on"
        ;;
    *"Make Discoverable"*)
        bluetoothctl discoverable on
        notify-send -u low -i bluetooth "Bluetooth" "Discoverable mode enabled"
        ;;
    *"Make Undiscoverable"*)
        bluetoothctl discoverable off
        notify-send -u low -i bluetooth "Bluetooth" "Discoverable mode disabled"
        ;;
    *"Scan for Nearby Devices"*)
        notify-send -u low -i bluetooth "Bluetooth" "Scanning for nearby devices (5 seconds)..."
        bluetoothctl --timeout 5 scan on >/dev/null 2>&1
        
        # Show discovered devices
        DISCOVERED=$(bluetoothctl devices | grep -v "^Device$" | while read -r _ mac name; do
            echo "󰂯  Pair & Connect: $name [$mac]"
        done)
        
        DEV_CHOICE=$(echo -e "$DISCOVERED\n󰒓  Open Blueman Manager" | rofi -dmenu -theme "$THEME" -p "󰂯 Scan Results" -mesg "Select a device to pair and connect")
        if [ -n "$DEV_CHOICE" ]; then
            if [[ "$DEV_CHOICE" == *"Open Blueman"* ]]; then
                blueman-manager &
            else
                TARGET_MAC=$(echo "$DEV_CHOICE" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
                if [ -n "$TARGET_MAC" ]; then
                    notify-send -u low -i bluetooth "Bluetooth" "Pairing with $TARGET_MAC..."
                    bluetoothctl pair "$TARGET_MAC"
                    bluetoothctl trust "$TARGET_MAC"
                    bluetoothctl connect "$TARGET_MAC"
                fi
            fi
        fi
        ;;
    *"Open Bluetooth Manager"*)
        blueman-manager &
        ;;
    *"Open Bluetooth Terminal"*)
        kitty -e bluetoothctl &
        ;;
    *"Disconnect: "*)
        TARGET_MAC=$(echo "$CHOICE" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
        if [ -n "$TARGET_MAC" ]; then
            bluetoothctl disconnect "$TARGET_MAC"
            notify-send -u low -i bluetooth "Bluetooth" "Disconnected device ($TARGET_MAC)"
        fi
        ;;
    *"Connect: "*)
        TARGET_MAC=$(echo "$CHOICE" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
        DEV_NAME=$(echo "$CHOICE" | sed -E 's/.*Connect: (.*) \[.*/\1/')
        if [ -n "$TARGET_MAC" ]; then
            notify-send -u low -i bluetooth "Bluetooth" "Connecting to $DEV_NAME..."
            if bluetoothctl connect "$TARGET_MAC"; then
                notify-send -i bluetooth "Bluetooth" "Connected to $DEV_NAME"
            else
                notify-send -u critical -i dialog-error "Bluetooth" "Failed to connect to $DEV_NAME"
            fi
        fi
        ;;
esac
