#!/bin/bash
# Outputs brightness as JSON for Waybar custom module with a visual bar

make_bar() {
    local pct=$1
    local width=20  # Number of bar segments
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="━"; done
    for ((i=0; i<empty; i++)); do bar+="─"; done
    bar+="]"
    echo "$bar"
}

# Try sysfs first
if [ -d /sys/class/backlight ]; then
    dev=$(ls /sys/class/backlight | head -n1)
    if [ -n "$dev" ] && [ -r "/sys/class/backlight/$dev/brightness" ] && [ -r "/sys/class/backlight/$dev/max_brightness" ]; then
        cur=$(cat "/sys/class/backlight/$dev/brightness")
        max=$(cat "/sys/class/backlight/$dev/max_brightness")
        if [ "$max" -gt 0 ]; then
            pct=$((100*cur/max))
        else
            pct=0
        fi
        bar=$(make_bar $pct)
        echo "{\"percentage\": $pct, \"text\": \"󰃠 $bar\"}"
        exit 0
    fi
fi
# Fallback to brightnessctl
if command -v brightnessctl >/dev/null 2>&1; then
    pct=$(brightnessctl -m | awk -F, '{gsub(/%/,"",$4); print int($4)}' | head -n1)
    bar=$(make_bar $pct)
    echo "{\"percentage\": $pct, \"text\": \"󰃠 $bar\"}"
    exit 0
fi
echo '{"percentage": 0, "text": "󰃠 [?-------------------]"}'
exit 1
