#!/usr/bin/env sh

set -u

if ! command -v eww >/dev/null 2>&1; then
  exit 0
fi

sleep 2

eww daemon >/dev/null 2>&1 || true

open_widget() {
  widget_name="$1"
  eww open "$widget_name" >/dev/null 2>&1 || true
}

open_widget time_widget
open_widget date_widget
open_widget week_widget
open_widget controls_icons_widget
