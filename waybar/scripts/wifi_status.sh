#!/usr/bin/env bash

WIFI_STATE=$(nmcli -t -f WIFI g 2>/dev/null)

if [ "$WIFI_STATE" != "enabled" ]; then
    echo '{"text": "󰖪", "class": "disconnected", "tooltip": "Wi-Fi: Disabled\nLeft-click: Wi-Fi Menu\nRight-click: Connection Editor"}'
    exit 0
fi

ACTIVE_LINE=$(nmcli -t -f IN-USE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^\*' | head -n1)
ACTIVE_SSID=$(echo "$ACTIVE_LINE" | cut -d: -f2)
ACTIVE_SIGNAL=$(echo "$ACTIVE_LINE" | cut -d: -f3)

if [ -n "$ACTIVE_SSID" ]; then
    WLAN_IFACE=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ':wifi$' | head -n1 | cut -d: -f1)
    IP_ADDR=""
    if [ -n "$WLAN_IFACE" ]; then
        IP_ADDR=$(ip -4 -br addr show dev "$WLAN_IFACE" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
    fi
    
    TOOLTIP="Wi-Fi: Connected\nSSID: $ACTIVE_SSID\nSignal: ${ACTIVE_SIGNAL}%\nIP: ${IP_ADDR:-N/A}\n\nLeft-click: Wi-Fi Menu\nRight-click: Connection Editor"
    echo "{\"text\": \"󰖩\", \"class\": \"connected\", \"tooltip\": \"$TOOLTIP\"}"
else
    echo '{"text": "󰖩", "class": "disconnected", "tooltip": "Wi-Fi: Disconnected\nLeft-click: Wi-Fi Menu\nRight-click: Connection Editor"}'
fi
