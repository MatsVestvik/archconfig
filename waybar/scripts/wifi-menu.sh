#!/usr/bin/env bash

THEME="$HOME/.config/rofi/widget-menu.rasi"

# Get current Wi-Fi radio status
WIFI_STATE=$(nmcli -t -f WIFI g 2>/dev/null)

# Get current active Wi-Fi connection info
ACTIVE_LINE=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi 2>/dev/null | grep '^\*' | head -n1)
ACTIVE_SSID=$(echo "$ACTIVE_LINE" | cut -d: -f2)
ACTIVE_SIGNAL=$(echo "$ACTIVE_LINE" | cut -d: -f3)

# Get current IP on wireless interface
WLAN_IFACE=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ':wifi$' | head -n1 | cut -d: -f1)
IP_ADDR=""
if [ -n "$WLAN_IFACE" ]; then
    IP_ADDR=$(ip -4 -br addr show dev "$WLAN_IFACE" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
fi

# Build Status Message
if [ "$WIFI_STATE" != "enabled" ]; then
    STATUS_MSG="Wi-Fi is currently disabled"
elif [ -n "$ACTIVE_SSID" ]; then
    STATUS_MSG="Connected to: $ACTIVE_SSID (${ACTIVE_SIGNAL}% signal) | IP: ${IP_ADDR:-N/A}"
else
    STATUS_MSG="Wi-Fi enabled | Not connected"
fi

# Build options list
OPTIONS=""

# 1. Wi-Fi Toggle
if [ "$WIFI_STATE" = "enabled" ]; then
    OPTIONS+="󰖩  Disable Wi-Fi\n"
    OPTIONS+="󰑐  Rescan Networks\n"
    if [ -n "$ACTIVE_SSID" ]; then
        OPTIONS+="󱚵  Disconnect from $ACTIVE_SSID\n"
    fi
else
    OPTIONS+="󰖪  Enable Wi-Fi\n"
fi

# 2. Recommended Managers
OPTIONS+="󱚶  Open Wi-Fi Settings (Connection Editor GUI)\n"
OPTIONS+="󰒓  Open Wi-Fi Terminal Manager (nmtui)\n"

# 3. Available Networks list (if Wi-Fi is enabled)
if [ "$WIFI_STATE" = "enabled" ]; then
    # Fetch, filter empty, deduplicate keeping highest signal
    RAW_NETWORKS=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null)
    
    # Process networks
    PARSED_NETWORKS=$(echo "$RAW_NETWORKS" | awk -F: '
    BEGIN { OFS=":" }
    {
        in_use = $1
        ssid = $2
        signal = $3
        sec = $4
        if (ssid != "" && !(ssid in seen)) {
            seen[ssid] = 1
            print in_use, ssid, signal, sec
        }
    }' | sort -t: -k3 -nr)

    while IFS=: read -r in_use ssid signal sec; do
        [ -z "$ssid" ] && continue
        
        # Determine Signal Icon
        if [ "$signal" -ge 75 ]; then
            icon="󰤨 "
        elif [ "$signal" -ge 50 ]; then
            icon="󰤥 "
        elif [ "$signal" -ge 25 ]; then
            icon="󰤢 "
        else
            icon="󰤟 "
        fi
        
        if [ "$in_use" = "*" ]; then
            OPTIONS+="$icon $ssid  (${signal}% - ${sec:-Open}) [Connected]\n"
        else
            OPTIONS+="$icon $ssid  (${signal}% - ${sec:-Open})\n"
        fi
    done <<< "$PARSED_NETWORKS"
fi

# Show rofi menu
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -theme "$THEME" -p "󰖩 Wi-Fi" -mesg "$STATUS_MSG")

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    *"Disable Wi-Fi"*)
        nmcli radio wifi off
        notify-send -u low -i network-wireless-offline "Wi-Fi" "Wi-Fi turned off"
        ;;
    *"Enable Wi-Fi"*)
        nmcli radio wifi on
        notify-send -u low -i network-wireless "Wi-Fi" "Wi-Fi turned on"
        ;;
    *"Rescan Networks"*)
        notify-send -u low -i network-wireless "Wi-Fi" "Scanning for networks..."
        nmcli dev wifi rescan
        exec "$0"
        ;;
    *"Disconnect from"*)
        if [ -n "$ACTIVE_SSID" ]; then
            nmcli con down id "$ACTIVE_SSID" 2>/dev/null || nmcli dev disconnect "$WLAN_IFACE" 2>/dev/null
            notify-send -u normal -i network-wireless-disconnected "Wi-Fi" "Disconnected from $ACTIVE_SSID"
        fi
        ;;
    *"Open Wi-Fi Settings"*)
        nm-connection-editor &
        ;;
    *"Open Wi-Fi Terminal Manager"*)
        kitty -e nmtui &
        ;;
    *)
        # Extract selected SSID (remove icon and trailing signal/sec info)
        # Choice format: "icon SSID  (XX% - SEC) [Connected]"
        SELECTED_SSID=$(echo "$CHOICE" | sed -E 's/^[^ ]+[ ]+//; s/[ ]+\([0-9]+%.*//; s/[ ]+\[Connected\]//')
        
        [ -z "$SELECTED_SSID" ] && exit 0
        
        if [ "$SELECTED_SSID" = "$ACTIVE_SSID" ]; then
            ACTION=$(echo -e "󱚵  Disconnect\n󰑐  Reconnect" | rofi -dmenu -theme "$THEME" -p "$SELECTED_SSID" -mesg "Currently connected to $SELECTED_SSID")
            if [ "$ACTION" = "󱚵  Disconnect" ]; then
                nmcli con down id "$SELECTED_SSID" 2>/dev/null || nmcli dev disconnect "$WLAN_IFACE"
                notify-send -i network-wireless-disconnected "Wi-Fi" "Disconnected from $SELECTED_SSID"
            elif [ "$ACTION" = "󰑐  Reconnect" ]; then
                nmcli con up id "$SELECTED_SSID"
                notify-send -i network-wireless "Wi-Fi" "Reconnected to $SELECTED_SSID"
            fi
            exit 0
        fi

        # Check if network is already saved in NetworkManager connections
        SAVED_CONN=$(nmcli -t -f NAME con show | grep -Fx "$SELECTED_SSID")
        
        notify-send -u low -i network-wireless "Wi-Fi" "Connecting to $SELECTED_SSID..."
        
        if [ -n "$SAVED_CONN" ]; then
            if nmcli con up id "$SELECTED_SSID"; then
                notify-send -i network-wireless "Wi-Fi" "Successfully connected to $SELECTED_SSID"
            else
                notify-send -u critical -i dialog-error "Wi-Fi" "Failed to connect to $SELECTED_SSID"
            fi
        else
            # Check security requirement
            if echo "$CHOICE" | grep -q "Open"; then
                if nmcli dev wifi connect "$SELECTED_SSID"; then
                    notify-send -i network-wireless "Wi-Fi" "Successfully connected to $SELECTED_SSID"
                else
                    notify-send -u critical -i dialog-error "Wi-Fi" "Failed to connect to $SELECTED_SSID"
                fi
            else
                PASS=$(rofi -dmenu -password -theme "$THEME" -p "Password" -mesg "Enter password for $SELECTED_SSID")
                if [ -n "$PASS" ]; then
                    if nmcli dev wifi connect "$SELECTED_SSID" password "$PASS"; then
                        notify-send -i network-wireless "Wi-Fi" "Successfully connected to $SELECTED_SSID"
                    else
                        notify-send -u critical -i dialog-error "Wi-Fi" "Failed to connect to $SELECTED_SSID. Incorrect password or timeout."
                    fi
                fi
            fi
        fi
        ;;
esac
