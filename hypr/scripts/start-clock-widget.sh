#!/usr/bin/env sh

set -eu

if ! command -v eww >/dev/null 2>&1; then
  exit 0
fi

eww daemon
eww open time_widget
eww open date_widget
eww open week_widget
eww open controls_icons_widget
