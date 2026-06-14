#!/usr/bin/env bash
# Shi — Toggle the agent TUI (Sway version)
# Three-state toggle: show / hide / launch
#
# Uses sway marks for window targeting — no temp files, no tree search.
# The window is marked "shi-tui" on creation and targeted by [con_mark=shi-tui].

set -euo pipefail

MARK="shi-tui"
APP_ID="shi-tui"
WIDTH=1400
HEIGHT=800
TOP_MARGIN=20

# Does a window with our mark exist?
is_marked() {
  swaymsg -t get_tree | jq -e --arg m "$MARK" \
    '[.. | objects | select(.marks // [] | any(. == $m))] | length > 0' \
    >/dev/null 2>&1
}

# Center-top position on the active output
position_window() {
  local pos
  pos=$(swaymsg -t get_outputs | jq -r --argjson w "$WIDTH" --argjson t "$TOP_MARGIN" '
    [.[] | select(.active)][0].rect
    | if . then [((.width - $w) / 2 | floor | if . < 0 then 0 else . end), $t] | map(tostring) | join(" ")
      else "260 20" end
  ' 2>/dev/null || echo "260 20")
  swaymsg "[con_mark=$MARK] resize set ${WIDTH} ${HEIGHT}" >/dev/null 2>&1
  swaymsg "[con_mark=$MARK] move position $pos" >/dev/null 2>&1
  swaymsg "[con_mark=$MARK] focus" >/dev/null 2>&1
}

# --- Main ---

if ! is_marked; then
  # Not running — launch it
  kitty --class "$APP_ID" --title "Shi" \
    -o confirm_os_window_close=0 \
    -o background_opacity=0.92 \
    -e hermes --tui -c -s sway-desktop,tmux &

  # Wait for the window to appear, then mark it
  for _ in $(seq 1 30); do
    sleep 0.3
    # Find by app_id and mark it
    swaymsg -t get_tree | jq -r --arg a "$APP_ID" \
      '[.. | objects | select(.app_id == $a and (.marks // [] | length == 0))] | first.id // empty' \
      | while read -r wid; do
          [ -n "$wid" ] && swaymsg "[con_id=$wid] mark --add $MARK" >/dev/null 2>&1
        done
    if is_marked; then
      position_window
      break
    fi
  done
else
  # Window exists — toggle
  swaymsg "[con_mark=$MARK] scratchpad show" >/dev/null 2>&1
#  position_window
fi
