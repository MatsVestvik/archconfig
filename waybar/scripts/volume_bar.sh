#!/usr/bin/env bash

set -u

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

vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00")
vol=$(echo "$vol_raw" | awk '{print $2}')

pct=$(awk -v v="$vol" 'BEGIN {printf "%.0f", v * 100}')
case "$pct" in
	""|*[!0-9]*) pct=0 ;;
esac

if ((pct < 0)); then pct=0; fi
if ((pct > 100)); then pct=100; fi

bar=$(make_bar $pct)

if echo "$vol_raw" | grep -q MUTED; then
	icon="󰖁"
	class="muted"
elif ((pct >= 80)); then
	icon="󰕾"
	class="high"
elif ((pct >= 50)); then
	icon="󰕾"
	class="medium"
elif ((pct >= 20)); then
	icon="󰕾"
	class="low"
else
	icon="󰕾"
	class="critical"
fi

text="$icon $bar"
printf '{"text":"%s","class":"%s"}\n' "$text" "$class"
