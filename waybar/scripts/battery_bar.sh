#!/usr/bin/env bash

set -u

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

bar_len=24
filled=$((capacity * bar_len / 100))
if ((filled < 0)); then filled=0; fi
if ((filled > bar_len)); then filled=$bar_len; fi
empty=$((bar_len - filled))

filled_bar=$(printf '%*s' "$filled" '' | tr ' ' '=')
empty_bar=$(printf '%*s' "$empty" '' | tr ' ' '-')

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

text="$icon [${filled_bar}${empty_bar}]"
printf '{"text":"%s","class":"%s"}\n' "$text" "$class"
