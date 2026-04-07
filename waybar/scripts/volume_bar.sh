#!/usr/bin/env bash

set -u

vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00")
vol=$(echo "$vol_raw" | awk '{print $2}')

pct=$(awk -v v="$vol" 'BEGIN {printf "%.0f", v * 100}')
case "$pct" in
	""|*[!0-9]*) pct=0 ;;
esac

if ((pct < 0)); then pct=0; fi
if ((pct > 100)); then pct=100; fi

bar_len=20
filled=$((pct * bar_len / 100))
empty=$((bar_len - filled))

filled_bar=$(printf '%*s' "$filled" '' | tr ' ' '=')
empty_bar=$(printf '%*s' "$empty" '' | tr ' ' '-')

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

pct_str=$(printf "%3d" "$pct")
text="$icon [${filled_bar}${empty_bar}] ${pct_str}%"
printf '{"text":"%s","class":"%s"}\n' "$text" "$class"
