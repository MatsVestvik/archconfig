#!/usr/bin/env sh

set -eu

if ! command -v eww >/dev/null 2>&1; then
  exit 0
fi

eww daemon
eww open clock_widget
