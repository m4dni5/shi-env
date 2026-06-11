#!/usr/bin/env bash
# Shi — Toggle the agent TUI
# If the Shi TUI is visible, hide it in the scratchpad.
# If it's in the scratchpad, show it.
# If it's not running, launch it.

set -euo pipefail

CLASS="shi-tui"
WIDTH=1400
HEIGHT=800
TOP_MARGIN=20

# Calculate center-top position from the active output
get_center_top() {
  DISPLAY=:0 i3-msg -t get_outputs | python3 -c "
import json, sys
outputs = json.load(sys.stdin)
for o in outputs:
    if o.get('active') and o.get('current_workspace'):
        rect = o.get('rect', {})
        out_w = rect.get('width', 1920)
        pad = max(0, (out_w - $WIDTH) // 2)
        print(f'{pad} {$TOP_MARGIN}')
        sys.exit(0)
print('260 20')
" 2>/dev/null || echo "260 20"
}

# Apply size and center-top position to the shi-tui window
position_window() {
  local pos
  pos=$(get_center_top)
  DISPLAY=:0 i3-msg "[class=\"$CLASS\"] resize set ${WIDTH} ${HEIGHT}" >/dev/null 2>&1
  DISPLAY=:0 i3-msg "[class=\"$CLASS\"] move position ${pos}" >/dev/null 2>&1
}

# Is the window visible right now? (not in scratchpad)
# Must check parent path: when hidden in __i3_scratch, the leaf window node
# still has scratchpad_state='none' — the actual hidden state is on the
# parent floating_con or the fact that it's under __i3_scratch.
VISIBLE=$(DISPLAY=:0 i3-msg -t get_tree | python3 -c "
import json, sys
tree = json.load(sys.stdin)

def find_visible(node, path_contains_scratch=False):
    if node.get('type') == 'workspace' and node.get('name') == '__i3_scratch':
        path_contains_scratch = True
    w = node.get('window_properties', {}).get('class', '') or ''
    if w == 'shi-tui':
        return not path_contains_scratch
    for c in node.get('nodes', []) + node.get('floating_nodes', []):
        if find_visible(c, path_contains_scratch):
            return True
    return False

print('yes' if find_visible(tree) else 'no')
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
    # Wait for the window to appear, then position it
    for _ in $(seq 1 20); do
      if DISPLAY=:0 i3-msg -t get_tree | python3 -c "
import json, sys
tree = json.load(sys.stdin)
def w(node):
    if node.get('window_properties', {}).get('class', '') == 'shi-tui': sys.exit(0)
    for c in node.get('nodes', []) + node.get('floating_nodes', []): w(c)
w(tree)
" 2>/dev/null; then
        position_window
        break
      fi
      sleep 0.3
    done
  else
    # Shown from scratchpad — reposition it
    position_window
  fi
fi
