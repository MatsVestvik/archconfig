#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import time

THEME = os.path.expanduser("~/.config/rofi/widget-menu.rasi")

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode('utf-8')
    except Exception:
        return ""

def get_audio_state():
    try:
        cards_raw = run_cmd(["pactl", "-f", "json", "list", "cards"])
        sinks_raw = run_cmd(["pactl", "-f", "json", "list", "sinks"])
        info_raw = run_cmd(["pactl", "-f", "json", "info"])
        
        cards = json.loads(cards_raw) if cards_raw else []
        sinks = json.loads(sinks_raw) if sinks_raw else []
        info = json.loads(info_raw) if info_raw else {}
        return cards, sinks, info
    except Exception:
        return [], [], {}

def get_current_volume_and_mute(default_sink, sinks):
    for s in sinks:
        if s.get("name") == default_sink:
            vol = s.get("volume", {}).get("front-left", {}).get("value_percent", "0%")
            mute = s.get("mute", False)
            return vol, mute
    return "0%", False

def main():
    cards, sinks, info = get_audio_state()
    default_sink = info.get("default_sink_name", "")
    
    sof_card = None
    for c in cards:
        if "skl_hda" in c.get("name", "") or "sof" in c.get("name", ""):
            sof_card = c
            break

    active_profile = sof_card.get("active_profile", "") if sof_card else ""
    vol_str, is_muted = get_current_volume_and_mute(default_sink, sinks)
    mute_label = "Muted" if is_muted else "Unmuted"

    # Build devices list
    devices = []

    # 1. Built-in Speakers
    is_spk_active = ("Speaker" in active_profile and "Speaker" in default_sink)
    devices.append({
        "type": "profile_sink",
        "label": "Built-in Speakers",
        "icon": "🔊",
        "card": sof_card.get("name") if sof_card else None,
        "profile": "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)",
        "sink_pattern": "HiFi__Speaker__sink",
        "active": is_spk_active
    })

    # 2. Wired Headphones
    is_hp_active = ("Headphones" in active_profile and "Headphones" in default_sink)
    devices.append({
        "type": "profile_sink",
        "label": "Wired Headphones (3.5mm)",
        "icon": "🎧",
        "card": sof_card.get("name") if sof_card else None,
        "profile": "HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1, Mic2)",
        "sink_pattern": "HiFi__Headphones__sink",
        "active": is_hp_active
    })

    # 3. HDMI / DisplayPort outputs
    for s in sinks:
        sname = s.get("name", "")
        if "HDMI" in sname or "hdmi" in sname:
            desc = s.get("description", "HDMI Output")
            clean_desc = desc.replace("Core Ultra 200V Series Processors HD Audio ", "")
            # Check port properties for monitor product name
            ports = s.get("ports", [])
            for p in ports:
                pname = p.get("properties", {}).get("device.product.name")
                if pname:
                    clean_desc = f"{pname} ({clean_desc})"
            is_active = (sname == default_sink)
            devices.append({
                "type": "sink",
                "label": f"HDMI / DisplayPort: {clean_desc}",
                "icon": "📺",
                "sink_name": sname,
                "active": is_active
            })

    # 4. Bluetooth devices
    for s in sinks:
        sname = s.get("name", "")
        if "bluez" in sname:
            desc = s.get("description", "Bluetooth Audio")
            is_active = (sname == default_sink)
            devices.append({
                "type": "sink",
                "label": f"Bluetooth: {desc}",
                "icon": "🎧",
                "sink_name": sname,
                "active": is_active
            })
        elif "usb" in sname:
            desc = s.get("description", "USB Audio Device")
            is_active = (sname == default_sink)
            devices.append({
                "type": "sink",
                "label": f"USB Audio: {desc}",
                "icon": "🎙️",
                "sink_name": sname,
                "active": is_active
            })

    # Find current active label
    current_label = "Unknown Device"
    for d in devices:
        if d.get("active"):
            current_label = f"{d['icon']} {d['label']}"
            break

    status_msg = f"Active: {current_label}  |  Volume: {vol_str} ({mute_label})"

    # Build Rofi options
    options_list = []
    option_map = {}

    for d in devices:
        active_tag = "  ✔ [ACTIVE]" if d.get("active") else ""
        opt_text = f"{d['icon']}  {d['label']}{active_tag}"
        options_list.append(opt_text)
        option_map[opt_text] = d

    # Actions
    mute_action_text = "󰖁  Toggle Mute / Unmute"
    options_list.append(mute_action_text)
    option_map[mute_action_text] = {"type": "action", "action": "toggle_mute"}

    pavu_text = "󰒓  PulseAudio Volume Control (GUI)"
    options_list.append(pavu_text)
    option_map[pavu_text] = {"type": "action", "action": "pavucontrol"}

    alsa_text = "💻  ALSA Mixer (Terminal)"
    options_list.append(alsa_text)
    option_map[alsa_text] = {"type": "action", "action": "alsamixer"}

    rofi_input = "\n".join(options_list)

    cmd = [
        "rofi",
        "-dmenu",
        "-theme", THEME,
        "-p", "󰕾 Sound Output",
        "-mesg", status_msg
    ]

    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        stdout, _ = proc.communicate(input=rofi_input)
    except Exception:
        sys.exit(1)

    choice = stdout.strip()
    if not choice or choice not in option_map:
        sys.exit(0)

    selected = option_map[choice]
    stype = selected.get("type")

    if stype == "action":
        act = selected.get("action")
        if act == "toggle_mute":
            subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"], check=False)
            subprocess.run(["notify-send", "-i", "audio-volume-muted", "-t", "1000", "-h", "string:x-dunst-stack-tag:volume_notif", "Audio Mute", "Mute Toggled"], check=False)
        elif act == "pavucontrol":
            subprocess.Popen(["pavucontrol"])
        elif act == "alsamixer":
            subprocess.Popen(["kitty", "-e", "alsamixer"])
    elif stype in ["profile_sink", "sink"]:
        card = selected.get("card")
        profile = selected.get("profile")
        sink_pattern = selected.get("sink_pattern")
        sink_name = selected.get("sink_name")

        if card and profile:
            subprocess.run(["pactl", "set-card-profile", card, profile], check=False)
            time.sleep(0.05)
            _, sinks_new, _ = get_audio_state()
            for s in sinks_new:
                if sink_pattern in s.get("name", ""):
                    sink_name = s.get("name")
                    break

        if sink_name:
            subprocess.run(["pactl", "set-default-sink", sink_name], check=False)
            subprocess.run(["pactl", "set-sink-mute", sink_name, "0"], check=False)
            subprocess.run(["amixer", "-c", "0", "sset", "Master", "unmute"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["amixer", "-c", "0", "sset", "Speaker", "unmute"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["amixer", "-c", "0", "sset", "Headphone", "unmute"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            try:
                inputs = subprocess.check_output(["pactl", "list", "short", "sink-inputs"], text=True)
                for line in inputs.strip().splitlines():
                    if line:
                        inp_id = line.split()[0]
                        subprocess.run(["pactl", "move-sink-input", inp_id, sink_name], check=False)
            except Exception:
                pass

        subprocess.run([
            "notify-send",
            "-i", "audio-speakers",
            "-t", "2000",
            "-h", "string:x-dunst-stack-tag:audio_switch",
            "Sound Output Switched",
            f"Active: {selected.get('icon', '🔊')} {selected.get('label')}"
        ], check=False)

if __name__ == "__main__":
    main()
