#!/usr/bin/env bash
# Shi — Toggle the agent TUI
# If the Shi TUI is running, toggle its scratchpad visibility.
# If it's not running, launch it.

set -euo pipefail

CLASS="shi-tui"
WIDTH=1400
HEIGHT=800
TOP_MARGIN=20

# Calculate center-top position from the active output
get_center_top() {
  DISPLAY=:0 i3-msg -t get_outputs | jq -r --argjson w "$WIDTH" --argjson t "$TOP_MARGIN" '
    [.[] | select(.active and .current_workspace)][0].rect
    | if . then [((.width - $w) / 2 | floor | if . < 0 then 0 else . end), $t] | map(tostring) | join(" ")
      else "260 20" end
  ' 2>/dev/null || echo "260 20"
}

# Apply size and center-top position to the shi-tui window
position_window() {
  DISPLAY=:0 i3-msg "[class=\"$CLASS\"] resize set ${WIDTH} ${HEIGHT}" >/dev/null 2>&1
  DISPLAY=:0 i3-msg "[class=\"$CLASS\"] move position $(get_center_top)" >/dev/null 2>&1
}

# Does the shi-tui window exist in the tree at all?
window_exists() {
  DISPLAY=:0 i3-msg -t get_tree | jq -e '
    [.. | .window_properties? // empty | select(.class == "shi-tui")] | length > 0
  ' >/dev/null 2>&1
}

if window_exists; then
  # Toggle scratchpad visibility and reposition
  DISPLAY=:0 i3-msg "[class=\"$CLASS\"] scratchpad show; [class=\"$CLASS\"] focus" >/dev/null 2>&1
  position_window
else
  # Not running — launch it
  kitty --class "$CLASS" --title "Shi" \
    -o confirm_os_window_close=0 \
    -o background_opacity=0.92 \
    -e hermes --tui -c -s i3-desktop,tmux &
  # Wait for the window to appear, then position it
  for _ in $(seq 1 20); do
    if window_exists; then
      position_window
      break
    fi
    sleep 0.3
  done
fi
