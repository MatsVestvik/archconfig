#!/usr/bin/env bash

default_color="rgba(323f4caa)"

get_color() {
    case "$1" in
        1) echo "rgba(a6da95ff)" ;;
        2) echo "rgba(8bd5caff)" ;;
        3) echo "rgba(eed49fff)" ;;
        4) echo "rgba(ed8796ff)" ;;
        5) echo "rgba(f5bde6ff)" ;;
        *) echo "$default_color" ;;
    esac
}

set_border_for_workspace() {
    local workspace_id="$1"
    local color
    color="$(get_color "$workspace_id")"
    hyprctl keyword general:col.active_border "$color" >/dev/null 2>&1
}

last_workspace=""

while true; do
    workspace_id="$(hyprctl activeworkspace -j 2>/dev/null | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([-0-9]\+\).*/\1/p' | head -n 1)"

    if [[ -n "$workspace_id" && "$workspace_id" != "$last_workspace" ]]; then
        set_border_for_workspace "$workspace_id"
        last_workspace="$workspace_id"
    fi

    sleep 0.2
done
