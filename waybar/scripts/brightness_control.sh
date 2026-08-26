#!/usr/bin/env bash

# Usage:
#   brightness_control.sh internal [status|up|down]
#   brightness_control.sh external [status|up|down]

TARGET="${1:-internal}"
ACTION="${2:-status}"

# Helper function to generate visual bar
make_bar() {
    local pct=$1
    local width=15
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="━"; done
    for ((i=0; i<empty; i++)); do bar+="─"; done
    bar+="]"
    echo "$bar"
}

if [ "$TARGET" = "internal" ]; then
    # Laptop screen backlight (intel_backlight)
    case "$ACTION" in
        up)
            brightnessctl -d "intel_backlight" set 5%+ >/dev/null 2>&1
            ;;
        down)
            brightnessctl -d "intel_backlight" set 5%- >/dev/null 2>&1
            ;;
        status)
            if [ -d /sys/class/backlight/intel_backlight ]; then
                cur=$(cat /sys/class/backlight/intel_backlight/brightness 2>/dev/null)
                max=$(cat /sys/class/backlight/intel_backlight/max_brightness 2>/dev/null)
                if [ -n "$max" ] && [ "$max" -gt 0 ]; then
                    pct=$((100 * cur / max))
                else
                    pct=0
                fi
            else
                pct=$(brightnessctl -m | awk -F, '{gsub(/%/,"",$4); print int($4)}' | head -n1)
            fi
            pct=${pct:-0}
            bar=$(make_bar "$pct")
            echo "{\"percentage\": $pct, \"text\": \"󰃠 $bar\", \"tooltip\": \"Laptop Screen: $pct% (Scroll to adjust)\"}"
            ;;
    esac

elif [ "$TARGET" = "external" ]; then
    # External monitor (via ddcutil if available)
    CACHE_FILE="/tmp/waybar_ext_brightness"
    
    case "$ACTION" in
        up)
            if command -v ddcutil >/dev/null 2>&1; then
                ddcutil setvcp 10 + 5 --noverify >/dev/null 2>&1 &
            fi
            # Update cache
            cur=$(cat "$CACHE_FILE" 2>/dev/null || echo 70)
            new=$((cur + 5))
            [ "$new" -gt 100 ] && new=100
            echo "$new" > "$CACHE_FILE"
            ;;
        down)
            if command -v ddcutil >/dev/null 2>&1; then
                ddcutil setvcp 10 - 5 --noverify >/dev/null 2>&1 &
            fi
            # Update cache
            cur=$(cat "$CACHE_FILE" 2>/dev/null || echo 70)
            new=$((cur - 5))
            [ "$new" -lt 0 ] && new=0
            echo "$new" > "$CACHE_FILE"
            ;;
        status)
            if [ -f "$CACHE_FILE" ]; then
                pct=$(cat "$CACHE_FILE")
            elif command -v ddcutil >/dev/null 2>&1; then
                # Get current VCP 10 brightness
                val=$(ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}')
                if [ -n "$val" ]; then
                    pct="$val"
                    echo "$pct" > "$CACHE_FILE"
                else
                    pct=70
                fi
            else
                pct=70
            fi
            pct=${pct:-70}
            bar=$(make_bar "$pct")
            if command -v ddcutil >/dev/null 2>&1; then
                echo "{\"percentage\": $pct, \"text\": \"󰃠 $bar\", \"tooltip\": \"External Monitor: $pct% (Scroll to adjust)\"}"
            else
                echo "{\"percentage\": $pct, \"text\": \"󰃠 $bar\", \"tooltip\": \"External Monitor: $pct%\n(Install ddcutil to control external brightness)\"}"
            fi
            ;;
    esac
fi
