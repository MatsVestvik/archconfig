#!/usr/bin/env python3
import json
import subprocess
import sys
import time

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
    except Exception as e:
        return [], [], {}

def get_available_targets():
    cards, sinks, info = get_audio_state()
    default_sink = info.get("default_sink_name", "")
    
    targets = []
    # Find intel/realtek sof-hda card
    sof_card = None
    for c in cards:
        if "skl_hda" in c.get("name", "") or "sof" in c.get("name", ""):
            sof_card = c
            break

    # Build logical list of switchable devices
    # 1. Built-in Speaker
    targets.append({
        "id": "speaker",
        "label": "🔊 Built-in Speakers",
        "icon": "audio-speakers",
        "card": sof_card.get("name") if sof_card else None,
        "profile": "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)",
        "sink_pattern": "HiFi__Speaker__sink",
    })

    # 2. Wired Headphones
    targets.append({
        "id": "headphones",
        "label": "🎧 Wired Headphones (3.5mm)",
        "icon": "audio-headphones",
        "card": sof_card.get("name") if sof_card else None,
        "profile": "HiFi (HDMI1, HDMI2, HDMI3, Headphones, Mic1, Mic2)",
        "sink_pattern": "HiFi__Headphones__sink",
    })

    # 3. HDMI / DisplayPort outputs
    for s in sinks:
        sname = s.get("name", "")
        if "HDMI" in sname or "hdmi" in sname:
            desc = s.get("description", "HDMI Output")
            clean_desc = desc.replace("Core Ultra 200V Series Processors HD Audio ", "")
            targets.append({
                "id": sname,
                "label": f"📺 HDMI / DisplayPort ({clean_desc})",
                "icon": "video-display",
                "card": None,
                "profile": None,
                "sink_name": sname
            })

    # 4. Bluetooth / USB sinks
    for s in sinks:
        sname = s.get("name", "")
        if "bluez" in sname:
            desc = s.get("description", "Bluetooth Audio")
            targets.append({
                "id": sname,
                "label": f"🎧 Bluetooth ({desc})",
                "icon": "audio-headphones",
                "card": None,
                "profile": None,
                "sink_name": sname
            })
        elif "usb" in sname:
            desc = s.get("description", "USB Audio")
            targets.append({
                "id": sname,
                "label": f"🎙️ USB Audio ({desc})",
                "icon": "audio-card",
                "card": None,
                "profile": None,
                "sink_name": sname
            })

    # Determine currently active target
    current_target_idx = 0
    active_profile = sof_card.get("active_profile", "") if sof_card else ""
    
    for idx, t in enumerate(targets):
        if t["id"] == "speaker" and "Speaker" in active_profile and "Speaker" in default_sink:
            current_target_idx = idx
            break
        elif t["id"] == "headphones" and "Headphones" in active_profile and "Headphones" in default_sink:
            current_target_idx = idx
            break
        elif t.get("sink_name") and t["sink_name"] == default_sink:
            current_target_idx = idx
            break

    return targets, current_target_idx

def switch_to_target(target):
    card = target.get("card")
    profile = target.get("profile")
    sink_pattern = target.get("sink_pattern")
    sink_name = target.get("sink_name")

    if card and profile:
        subprocess.run(["pactl", "set-card-profile", card, profile], check=False)
        time.sleep(0.05)
        _, sinks, _ = get_audio_state()
        for s in sinks:
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
        "-i", target.get("icon", "audio-speakers"),
        "-t", "2000",
        "-h", "string:x-dunst-stack-tag:audio_switch",
        "Audio Output Switched",
        target.get("label", "Audio Device")
    ], check=False)

def main():
    targets, current_idx = get_available_targets()
    if not targets:
        sys.exit(1)

    next_idx = (current_idx + 1) % len(targets)
    next_target = targets[next_idx]
    switch_to_target(next_target)

if __name__ == "__main__":
    main()
