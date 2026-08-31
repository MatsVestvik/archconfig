#!/usr/bin/env bash

set -u

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

BAT_PATH="/sys/class/power_supply/BAT1"

if [[ -d "$BAT_PATH" ]]; then
  capacity=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo 0)
  status=$(cat "$BAT_PATH/status" 2>/dev/null || echo Unknown)
else
  capacity=0
  status=Unknown
fi

case "$capacity" in
  ""|*[!0-9]*) capacity=0 ;;
esac

bar=$(make_bar "$capacity")

if [[ "$status" == "Charging" ]]; then
  icon="󰂄"
  class="charging"
elif [[ "$status" == "Full" ]] || ((capacity >= 100)); then
  icon="󰁹"
  class="good"
elif ((capacity >= 80)); then
  icon="󰂂"
  class="good"
elif ((capacity >= 30)); then
  icon="󰁽"
  class="warning"
else
  icon="󰂎"
  class="critical"
fi

text="$icon $bar"
tooltip="Battery: $capacity% ($status)"
printf '{"text":"%s","class":"%s","percentage":%d,"tooltip":"%s"}\n' "$text" "$class" "$capacity" "$tooltip"
