#!/usr/bin/env bash

# Volume and audio control for Hyprland with Dunst notifications

volume_step=5
max_volume=100
notification_timeout=1000

get_volume() {
    vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00")
    vol=$(echo "$vol_raw" | awk '{print $2}')
    pct=$(awk -v v="$vol" 'BEGIN {printf "%.0f", v * 100}')
    case "$pct" in
        ""|*[!0-9]*) pct=0 ;;
    esac
    echo "$pct"
}

is_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q "\[MUTED\]" && echo "yes" || echo "no"
}

is_mic_muted() {
    wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q "\[MUTED\]" && echo "yes" || echo "no"
}

show_volume_notif() {
    volume=$(get_volume)
    muted=$(is_muted)
    if [ "$muted" = "yes" ] || [ "$volume" -eq 0 ]; then
        icon="audio-volume-muted"
        text="Muted ($volume%)"
    elif [ "$volume" -lt 30 ]; then
        icon="audio-volume-low"
        text="$volume%"
    elif [ "$volume" -lt 70 ]; then
        icon="audio-volume-medium"
        text="$volume%"
    else
        icon="audio-volume-high"
        text="$volume%"
    fi

    notify-send -i "$icon" -t "$notification_timeout" \
        -h string:x-dunst-stack-tag:volume_notif \
        -h int:value:"$volume" \
        "Volume" "$text"
}

show_mic_notif() {
    muted=$(is_mic_muted)
    if [ "$muted" = "yes" ]; then
        notify-send -i "microphone-sensitivity-muted" -t "$notification_timeout" \
            -h string:x-dunst-stack-tag:mic_notif \
            "Microphone" "Muted"
    else
        notify-send -i "microphone-sensitivity-high" -t "$notification_timeout" \
            -h string:x-dunst-stack-tag:mic_notif \
            "Microphone" "Active"
    fi
}

case "$1" in
    volume_up)
        # Unmute sink and hardware if muted
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null
        amixer -c 0 sset Master unmute >/dev/null 2>&1
        amixer -c 0 sset Speaker unmute >/dev/null 2>&1
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${volume_step}%+" 2>/dev/null
        show_volume_notif
        ;;
    volume_down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${volume_step}%-" 2>/dev/null
        show_volume_notif
        ;;
    volume_mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null
        show_volume_notif
        ;;
    mic_mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null
        show_mic_notif
        ;;
    init)
        # Ensure ALSA hardware mixer is unmuted and set to 100%
        amixer -c 0 sset Master unmute 100% >/dev/null 2>&1
        amixer -c 0 sset Speaker unmute 100% >/dev/null 2>&1
        amixer -c 0 sset Headphone unmute 100% >/dev/null 2>&1
        
        # Check current default sink, if not set or invalid, activate speaker profile
        cur_sink=$(pactl get-default-sink 2>/dev/null)
        if [ -z "$cur_sink" ] || [[ "$cur_sink" == *"HDMI"* ]]; then
            pactl set-card-profile alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)" 2>/dev/null
            pactl set-default-sink alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink 2>/dev/null
        fi
        ;;
esac
