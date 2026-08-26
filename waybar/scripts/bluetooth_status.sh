#!/usr/bin/env bash

BT_SHOW=$(bluetoothctl show 2>/dev/null)
if ! echo "$BT_SHOW" | grep -q "Powered: yes"; then
    echo '{"text": "󰂲", "class": "disconnected", "tooltip": "Bluetooth: Powered Off\nLeft-click: Bluetooth Menu\nRight-click: Blueman Manager"}'
    exit 0
fi

# Check for connected devices
DEVS=$(bluetoothctl devices Connected 2>/dev/null)
if [ -n "$DEVS" ]; then
    NAME=$(echo "$DEVS" | head -n1 | cut -d' ' -f3-)
    TOOLTIP="Bluetooth: Connected\nDevice: $NAME\n\nLeft-click: Bluetooth Menu\nRight-click: Blueman Manager"
    echo "{\"text\": \"󰂱\", \"class\": \"connected\", \"tooltip\": \"$TOOLTIP\"}"
else
    echo '{"text": "󰂯", "class": "connected", "tooltip": "Bluetooth: Powered On (No device connected)\nLeft-click: Bluetooth Menu\nRight-click: Blueman Manager"}'
fi
