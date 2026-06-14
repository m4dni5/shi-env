---
name: sway-desktop
description: "Control the Sway desktop — window management, kitty IPC, screenshots, clipboard, input simulation. Use when you need to move windows, launch apps, capture the screen, or interact with the desktop programmatically."
user-invocable: true
---

# Sway Desktop — Agent Automation Reference

## When to Use

Moving windows, launching apps, capturing the screen, reading the clipboard, controlling kitty programmatically.

**Don't use when:** working inside tmux (→ tmux skill), browsing the web (→ CDP/browser tools), running a one-shot command (→ terminal).

## Prerequisites

Sway sets `WAYLAND_DISPLAY` automatically. No `DISPLAY` needed. From SSH, set `SWAYSOCK`:
```bash
export SWAYSOCK=/run/user/$(id -u)/sway-ipc.$(id -u).$(pgrep -x sway).sock
```

---

## Mental Model

```
swaymsg → sway compositor → workspaces → containers (app_id / title / marks)
kitten @ → kitty terminal → tabs → windows (id / title / cmdline)
grim / slurp → screenshots          wl-copy / wl-paste → clipboard
ydotool / wtype → input simulation  chromium → CDP (port 9222)
```

**swaymsg** controls the WM. **kitten @** controls kitty. **CDP** controls the browser. Everything else is fallback.

---

## OBSERVE — See What's on the Desktop

### Window Tree (primary tool)

```bash
swaymsg -t get_tree
```

List all windows with workspace context:
```bash
swaymsg -t get_tree | jq -r '
  def walk($ws):
    if .type == "workspace" then
      .name as $n | .nodes[], .floating_nodes[] | walk($n)
    elif ((.nodes // []) | length) > 0 or ((.floating_nodes // []) | length) > 0 then
      .nodes[], .floating_nodes[] | walk($ws)
    else
      .app_id // empty | "\($ws): \(.)"
    end;
  [walk("")] | map(select(startswith("__i3_scratch") | not)) | sort | .[]
'
```

Find a specific window by app_id:
```bash
swaymsg -t get_tree | jq '[.. | objects | select(.app_id == "kitty")] | first | {id, name, visible}'
```

### Window Criteria (swaymsg selectors)

Native Wayland apps use `app_id`. XWayland apps use `class`. Both support `title`, `con_id`, `mark`.

```bash
swaymsg '[app_id="kitty"] focus'          # native Wayland
swaymsg '[class="Firefox"] focus'          # XWayland
swaymsg '[title="htop"] focus'            # by title
swaymsg '[con_id=42] focus'               # by container ID
```

### Outputs and Workspaces

```bash
swaymsg -t get_outputs | jq '.[] | {name, active, rect, current_workspace}'
swaymsg -t get_workspaces | jq '.[] | {name, output, focused, visible}'
```

### Kitty Windows

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
kitten @ --to "unix:$SOCK" ls | jq '.. | .windows? // empty | .[] | {id, title, is_focused}'
```

Match by cmdline (when title is unreliable, e.g. hermes --tui):
```bash
kitten @ --to "unix:$SOCK" ls | jq -r '
  [.. | .windows? // empty | .[] |
   select(.cmdline | map(select(. != null)) | join(" ") | contains("hermes"))] |
  first.id // empty
'
```

---

## ACT — Control the Desktop

### Window Management

```bash
swaymsg 'workspace 2'                                  # switch workspace
swaymsg 'move container to workspace 3'                # move to workspace
swaymsg 'focus left' / 'focus down' / 'focus up' / 'focus right'
swaymsg '[app_id="kitty"] kill'                        # close window
swaymsg 'floating toggle'                              # toggle float
swaymsg 'fullscreen toggle'                            # fullscreen (single output)
swaymsg 'fullscreen toggle global'                     # fullscreen (all outputs)
swaymsg 'split h'                                      # next split: side-by-side
swaymsg 'split v'                                      # next split: stacked
swaymsg 'layout stacking' / 'layout tabbed' / 'layout toggle split'
swaymsg 'focus parent'                                 # focus enclosing container
swaymsg 'focus output DP-2'                            # focus a different monitor
swaymsg reload                                         # reload config
```

### Scratchpad

Sway's `scratchpad show` **toggles both directions** (unlike i3, where it only shows). A visible scratchpad window goes back to scratchpad on the same command.

```bash
swaymsg 'move scratchpad'                              # hide current window
swaymsg 'scratchpad show'                              # toggle (show or hide)
swaymsg '[con_id=42] scratchpad show'                  # toggle specific window
```

Check visibility after toggle:
```bash
swaymsg -t get_tree | jq --argjson id 42 \
  '[.. | objects | select(.id == $id)] | first.visible'
```

**Caveat:** `move position` on a hidden scratchpad window pulls it back out. Always check `visible` after toggling before positioning.

### Marks (named window targeting)

```bash
swaymsg 'mark --add myterm'                            # mark current window
swaymsg '[con_mark=myterm] focus'                      # focus by mark
swaymsg '[con_mark=myterm] move container to workspace 5'
```

### Opacity

```bash
swaymsg 'opacity 0.9'                                  # current window
swaymsg '[app_id="kitty"] opacity 0.8'                 # by app_id
```

### Kitty Remote Control

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)

kitten @ --to "unix:$SOCK" launch --type=window htop   # new window
kitten @ --to "unix:$SOCK" launch --type=tab bash       # new tab
kitten @ --to "unix:$SOCK" send-text --match id:1 'echo hello'
kitten @ --to "unix:$SOCK" send-key --match id:1 Enter  # actual keypress
kitten @ --to "unix:$SOCK" get-text --match id:1        # read contents
kitten @ --to "unix:$SOCK" close-window --match id:2    # close
kitten @ --to "unix:$SOCK" focus-window --match id:1    # focus
```

**send-text vs send-key:** `send-text` sends literal text. To press Enter, use `send-key Enter` separately. Two-step pattern for submitting commands:
```bash
kitten @ --to "unix:$SOCK" send-text --match id:1 "command"
kitten @ --to "unix:$SOCK" send-key --match id:1 Return
```

### Screenshots

```bash
grim ~/Screenshots/shot.png                            # full screen
grim -g "$(slurp)" ~/Screenshots/shot.png              # selection
grim -o DP-1 ~/Screenshots/shot.png                    # specific output
```

### Clipboard

```bash
wl-paste                                                # read
echo "text" | wl-copy                                   # write
wl-copy < file.txt                                      # write file
wl-paste --no-newline                                   # read without trailing newline
```

### Input Simulation

```bash
# Keyboard only (no daemon needed)
wtype 'text'
wtype -P Return

# Full input (requires ydotoold daemon)
ydotool type --delay 50 'text'
ydotool key Return
ydotool mousemove --absolute -x 500 -y 300
ydotool click 0xC0                                      # left click
ydotool click 0xC1                                      # right click
```

---

## GOTCHAS

1. **`app_id` vs `class`.** Wayland native apps → `app_id`. XWayland apps → `window_properties.class` / `[class="..."]`. Kitty is native Wayland.

2. **Kitty socket has a PID suffix.** Config says `listen_on unix:/tmp/kitty-ipc` but actual socket is `/tmp/kitty-ipc-{PID}`. Always discover: `ls -t /tmp/kitty-ipc-* | head -1`.

3. **`scratchpad show` toggles in sway.** In i3 it only shows. In sway it hides too. `move position` pulls hidden scratchpad windows back out — check `visible` before positioning.

4. **`scratchpad_state` is unreliable.** Use `.visible` field instead: `.. | objects | select(.id == $id) | .visible`.

5. **`for_window` rules only fire on window creation.** They don't re-trigger on `swaymsg` moves or shows. Safe to toggle windows in/out of scratchpad even with `for_window` rules.

6. **`exec` runs once; `exec_always` runs on every reload.** Use `exec_always` for waybar and anything that should survive `swaymsg reload`.

7. **PATH is minimal in keybinding scripts.** Sway inherits the login environment, not the user's shell. Prepend `$HOME/.local/bin` in scripts that call pip/pipx tools.

8. **No DISPLAY needed.** Sway sets `WAYLAND_DISPLAY`. From SSH, set `SWAYSOCK`.

9. **Transparency is built-in.** No picom. Use `swaymsg 'opacity 0.9'` or kitty's `background_opacity`.

10. **Gaps are built-in.** No i3-gaps package. `gaps inner` and `gaps outer` work directly.

11. **`swaymsg` returns JSON.** Parse it. `[{"success":true}]` = worked. `[{"success":false}]` = failed. Don't grep.

12. **`ydotoold` must be running.** Started by sway config. Check: `pgrep ydotoold`.

---

## RECIPES

### Launch app, read output, clean up
```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
kitten @ --to "unix:$SOCK" launch --type=window htop
sleep 2
kitten @ --to "unix:$SOCK" get-text --match id:2
kitten @ --to "unix:$SOCK" close-window --match id:2
```

### Screenshot and analyze
```bash
grim /tmp/desktop.png
# Then: vision_analyze(image_url='/tmp/desktop.png', question='...')
```

### Move window by app_id
```bash
swaymsg '[app_id="firefox"] move container to workspace 5'
```

### Copy file to clipboard
```bash
wl-copy < /path/to/file.txt
```

### Restore desktop after reboot
Sway config's `exec` section handles this. Manual fallback:
```bash
swaybg -i ~/wallpapers/vestige-dark.png -m fill &
swaymsg exec kitty
chromium --remote-debugging-port=9222 --no-first-run --no-default-browser-check &
ydotoold &
```
