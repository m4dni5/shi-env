#!/usr/bin/env bash
# Shi — Rofi one-shot agent prompt
# Quick question to Hermes via rofi. Response displayed in rofi or sent
# to the running TUI session if one is open.
#
# Usage: bound to $mod+a in i3 config

set -euo pipefail

# --- Input ---
prompt=$(rofi -dmenu -p "Ask agent" \
  -theme-str 'window {width: 600px;} listview {lines: 0;}')
[ -z "$prompt" ] && exit 0

# --- Try sending to running TUI session (kitty IPC) ---
SOCK=$(ls -t /tmp/kitty-ipc-* 2>/dev/null | head -1)
if [ -n "$SOCK" ]; then
  # Check if the hermes-tui window exists
  WIN_ID=$(DISPLAY=:0 kitten @ --to "unix:$SOCK" ls 2>/dev/null | \
    python3 -c "
import json, sys
for o in json.load(sys.stdin):
    for t in o.get('tabs', []):
        for w in t.get('windows', []):
            if w.get('title', '') == 'Shi':
                print(w['id'])
                sys.exit(0)
" 2>/dev/null) || true

  if [ -n "$WIN_ID" ]; then
    # TUI is running — send the prompt into it
    DISPLAY=:0 kitten @ --to "unix:$SOCK" \
      send-text --match id:"$WIN_ID" -l "$prompt"
    DISPLAY=:0 kitten @ --to "unix:$SOCK" \
      send-text --match id:"$WIN_ID" Enter
    # Show the TUI if it's hidden in scratchpad
    DISPLAY=:0 i3-msg '[class="shi-tui"] scratchpad show; focus' >/dev/null 2>&1
    exit 0
  fi
fi

# --- Fallback: one-shot hermes chat ---
response=$(hermes chat -q "$prompt" 2>/dev/null) || response="Agent unavailable."
echo "$response" | rofi -dmenu -p "Agent" \
  -theme-str 'window {width: 800px; height: 500px;} inputbar {enabled: false;}'
