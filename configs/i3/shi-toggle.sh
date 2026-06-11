#!/usr/bin/env bash
# Shi — Toggle the agent TUI
# If the Shi TUI is visible, hide it in the scratchpad.
# If it's in the scratchpad, show it.
# If it's not running, launch it.

set -euo pipefail

CLASS="shi-tui"

# Is the window visible right now? (not in scratchpad)
VISIBLE=$(DISPLAY=:0 i3-msg -t get_tree | python3 -c "
import json, sys
tree = json.load(sys.stdin)
def find(node):
    w = node.get('window_properties', {}).get('class', '') or ''
    if w == '$CLASS':
        # visible if it has a non-null rect and is not in scratchpad
        return node.get('scratchpad_state', 'none') != 'hidden' and node.get('rect', {}).get('width', 0) > 0
    for c in node.get('nodes', []) + node.get('floating_nodes', []):
        if find(c):
            return True
    return False
print('yes' if find(tree) else 'no')
" 2>/dev/null) || VISIBLE="no"

if [ "$VISIBLE" = "yes" ]; then
  # Hide it
  DISPLAY=:0 i3-msg "[class=\"$CLASS\"] move scratchpad" >/dev/null 2>&1
else
  # Try to show from scratchpad
  if ! DISPLAY=:0 i3-msg "[class=\"$CLASS\"] scratchpad show; [class=\"$CLASS\"] focus" >/dev/null 2>&1; then
    # Not running — launch it
    kitty --class "$CLASS" --title "Shi" \
      -o confirm_os_window_close=0 \
      -o background_opacity=0.92 \
      -e hermes --tui -c -s i3-desktop,tmux &
  fi
fi
