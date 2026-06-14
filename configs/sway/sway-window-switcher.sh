#!/usr/bin/env bash
# Shi — Sway window switcher
# Lists all windows from sway's tree, pipes through rofi as dmenu,
# focuses the selected window. Works with Wayland native apps.
#
# Usage: bound to $mod+Tab in sway config

set -euo pipefail

# Build window list from sway tree
# Format: "workspace: app_id — title"
WINDOW_LIST=$(swaymsg -t get_tree | jq -r '
  # Walk tree, carrying workspace name
  def walk($ws):
    if .type == "workspace" then
      .name as $name | .nodes[], .floating_nodes[] | walk($name)
    elif (.nodes | length) > 0 or (.floating_nodes | length) > 0 then
      .nodes[], .floating_nodes[] | walk($ws)
    else
      .app_id // empty | { app_id: ., ws: $ws }
    end;

  [ walk("") ]
  | map(select(.ws != "__i3_scratch" and .app_id != ""))
  | sort_by(.ws, .app_id)
  | .[]
  | "\(.ws): \(.app_id)"
' 2>/dev/null)

# Nothing to list
[ -z "$WINDOW_LIST" ] && exit 0

# Show in rofi (dmenu mode)
SELECTED=$(echo "$WINDOW_LIST" | rofi -dmenu -i -p "Window" -lines 10 -width 600 2>/dev/null)

# User cancelled
[ -z "$SELECTED" ] && exit 0

# Extract app_id from "workspace: app_id"
APP_ID=$(echo "$SELECTED" | sed 's/^[^:]*: //')

# Focus the window
if [ -n "$APP_ID" ]; then
    swaymsg "[app_id=\"$APP_ID\"] focus" 2>/dev/null || true
fi
