#!/usr/bin/env bash

set -u

ACTION="${1:-status}"

# Helper function to generate visual bar matching waybar theme
make_bar() {
    local pct=$1
    local width=10  # Number of bar segments
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="]"
    echo "$bar"
}

get_active_device_label() {
    local def_sink
    def_sink=$(pactl get-default-sink 2>/dev/null || echo "")
    
    if [[ "$def_sink" == *"Speaker"* ]]; then
        echo "🔊 Built-in Speakers"
    elif [[ "$def_sink" == *"Headphones"* ]]; then
        echo "🎧 Wired Headphones"
    elif [[ "$def_sink" == *"HDMI"* ]] || [[ "$def_sink" == *"hdmi"* ]]; then
        echo "📺 HDMI / DisplayPort"
    elif [[ "$def_sink" == *"bluez"* ]]; then
        echo "🎧 Bluetooth Audio"
    elif [[ "$def_sink" == *"usb"* ]]; then
        echo "🎙️ USB Audio"
    else
        echo "🔊 Built-in Speakers"
    fi
}

case "$ACTION" in
    up)
        # Unmute sink and hardware if muted
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null
        amixer -c 0 sset Master unmute >/dev/null 2>&1
        amixer -c 0 sset Speaker unmute >/dev/null 2>&1
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null
        ;;
    status)
        vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00")
        vol=$(echo "$vol_raw" | awk '{print $2}')

        pct=$(awk -v v="$vol" 'BEGIN {printf "%.0f", v * 100}')
        case "$pct" in
            ""|*[!0-9]*) pct=0 ;;
        esac

        if ((pct < 0)); then pct=0; fi
        if ((pct > 100)); then pct=100; fi

        bar=$(make_bar "$pct")
        dev_label=$(get_active_device_label)

        if echo "$vol_raw" | grep -q MUTED; then
            icon="󰖁"
            class="muted"
            mute_text="Muted"
        elif ((pct >= 80)); then
            icon="󰕾"
            class="high"
            mute_text="Unmuted"
        elif ((pct >= 50)); then
            icon="󰕾"
            class="medium"
            mute_text="Unmuted"
        elif ((pct >= 20)); then
            icon="󰕾"
            class="low"
            mute_text="Unmuted"
        else
            icon="󰕾"
            class="critical"
            mute_text="Unmuted"
        fi

        text="$icon $bar"
        tooltip="Sound Output: $dev_label\nVolume: $pct% ($mute_text)\n\n• Scroll: Adjust Volume\n• Left-click: Sound Exit Menu\n• Right-click: Pavucontrol\n• Middle-click: Toggle Mute"

        tooltip_json=$(echo -e "$tooltip" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')

        printf '{"text":"%s","class":"%s","percentage":%d,"tooltip":"%s"}\n' "$text" "$class" "$pct" "$tooltip_json"
        ;;
esac
