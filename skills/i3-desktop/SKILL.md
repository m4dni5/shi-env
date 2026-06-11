---
name: i3-desktop
description: "Control the i3 desktop environment — window management, kitty terminal remote control, screenshots, clipboard, wallpaper, and X11 automation. Use when you need to move windows, launch apps, capture the screen, or interact with the desktop programmatically."
user-invocable: true
---

# i3 Desktop — Agent Automation Reference

Drive the desktop from the shell. This covers the full automation surface: i3 window management, kitty terminal remote control, screenshots, clipboard, wallpaper, and X11 input simulation.

## When to Use

Use this skill when you need to:
- **Manage windows** — move, resize, focus, switch workspaces, tile, float
- **Control kitty** — launch windows, send commands, read terminal contents
- **Capture the screen** — full screenshots, selections, specific windows
- **Read/write the clipboard** — copy data between the agent and the desktop
- **Set the wallpaper** — change or restore the desktop background
- **Simulate input** — send keystrokes, move the mouse (non-kitty X11 apps)

Don't use this skill when:
- You're working inside tmux → use the **tmux** skill
- You're browsing the web → use the **browser** tools (CDP)
- You're running a one-shot command → use `terminal()`

## Prerequisites

All commands require the X display:
```bash
export DISPLAY=:0
```

This should be in `~/.bashrc`. If it's not set, X tools (`i3-msg`, `xdotool`, `maim`, `kitten @`) will fail with "Can't open display" or "unable to find display."

---

## Mental Model

```
i3 (window manager)
├── Workspaces (1-10)
│   ├── kitty (terminal) — controlled via kitten @
│   ├── chromium (browser) — controlled via CDP
│   └── other X apps — controlled via xdotool
├── i3bar (status bar)
└── i3status (metrics)

picom (compositor) — transparency, blur, shadows
feh (wallpaper) — background image
maim (screenshots) — screen capture
xsel (clipboard) — clipboard access
```

**i3-msg** controls the window manager layer.
**kitten @** controls the terminal emulator layer.
**xdotool** controls individual X11 windows (for apps without native remote control).
**maim** captures what's on screen.
**xsel** reads/writes the system clipboard.

> **Reference:** `references/quake-tui-toggle.md` — full template for a quake-style TUI dropdown in i3 with scratchpad toggle.

---

## OBSERVE — See What's on the Desktop

### Window Tree

The full i3 tree as JSON — your primary tool for understanding what's where:

```bash
DISPLAY=:0 i3-msg -t get_tree
```

Parse it to find windows by class, title, or workspace:

```bash
DISPLAY=:0 i3-msg -t get_tree | python3 -c "
import json, sys
tree = json.load(sys.stdin)
def walk(node, depth=0):
    name = node.get('name','') or ''
    cls = node.get('window_properties',{}).get('class','') or ''
    focused = node.get('focused', False)
    if name or cls:
        mark = ' ◄' if focused else ''
        print(f\"{'  '*depth}[{cls}] {name}{mark}\")
    for c in node.get('nodes',[]) + node.get('floating_nodes',[]):
        walk(c, depth+1)
walk(tree)
"
```

### Output/Monitor Info

```bash
DISPLAY=:0 i3-msg -t get_outputs
```

Returns JSON with monitor names, resolutions, positions, and current workspace.

### Current Workspace

```bash
DISPLAY=:0 i3-msg -t get_workspaces | python3 -c "
import json, sys
for ws in json.load(sys.stdin):
    focus = ' ◄' if ws['focused'] else ''
    print(f\"  {ws['name']} (output={ws['output']}){focus}\")
"
```

### Kitty Windows (via kitten @)

List all kitty windows/tabs:

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
DISPLAY=:0 kitten @ --to "unix:$SOCK" ls
```

Parse for a quick window list (by title):

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
DISPLAY=:0 kitten @ --to "unix:$SOCK" ls | python3 -c "
import json, sys
data = json.load(sys.stdin)
for os_win in data:
    for tab in os_win.get('tabs', []):
        for win in tab.get('windows', []):
            focused = ' ◄' if win.get('is_focused') else ''
            print(f'  [{win[\"id\"]}] {win.get(\"title\",\"\")} {focused}')
"
```

**Matching by cmdline instead of title**: Some applications (like `hermes --tui`) overwrite their window title after launch, so `w.get('title') == 'Fixed Title'` may fail. Match by cmdline instead when the title is unreliable:

```bash
for s in /tmp/kitty-ipc-*; do
  [ -S "$s" ] || continue
  DISPLAY=:0 kitten @ --to "unix:$s" ls | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    for t in o.get('tabs', []):
        for w in t.get('windows', []):
            cl = ' '.join(w.get('cmdline', []))
            if 'hermes' in cl and '--tui' in cl:
                print(f'{w[\"id\"]}')
                sys.exit(0)
"
  break
done
```

See `references/quake-tui-toggle.md` for a complete rofi-to-TUI IPC integration example.

Read terminal contents from a specific kitty window:

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
DISPLAY=:0 kitten @ --to "unix:$SOCK" get-text --match id:1
```

---

## ACT — Control the Desktop

### i3 Window Management

**Switch workspace:**
```bash
DISPLAY=:0 i3-msg 'workspace 2'
```

**Move focused window to workspace:**
```bash
DISPLAY=:0 i3-msg 'move container to workspace 3'
```

**Move focus (Vi-style):**
```bash
DISPLAY=:0 i3-msg 'focus left'
DISPLAY=:0 i3-msg 'focus down'
```

**Close window:**
```bash
DISPLAY=:0 i3-msg '[class="kitty"] kill'
```

**Toggle float:**
```bash
DISPLAY=:0 i3-msg 'floating toggle'
```

**Fullscreen:**
```bash
DISPLAY=:0 i3-msg 'fullscreen toggle'
```

**Split direction:**
```bash
DISPLAY=:0 i3-msg 'split h'    # horizontal (side by side)
DISPLAY=:0 i3-msg 'split v'    # vertical (stacked)
```

**Layout mode:**
```bash
DISPLAY=:0 i3-msg 'layout stacking'
DISPLAY=:0 i3-msg 'layout tabbed'
DISPLAY=:0 i3-msg 'layout toggle split'
```

**Reload config:**
```bash
DISPLAY=:0 i3-msg reload
```

**Scratchpad (hidden window stash):**
```bash
DISPLAY=:0 i3-msg 'move scratchpad'    # hide current window
DISPLAY=:0 i3-msg 'scratchpad show'    # cycle through scratchpad
```

### Kitty Remote Control

The kitty socket has a PID suffix. Always discover it dynamically:
```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
```

**Launch a new kitty window running a command:**
```bash
DISPLAY=:0 kitten @ --to "unix:$SOCK" launch --type=window htop
```

**Launch a new tab:**
```bash
DISPLAY=:0 kitten @ --to "unix:$SOCK" launch --type=tab bash
```

**Send text to a specific window (by ID):**
```bash
DISPLAY=:0 kitten @ --to "unix:$SOCK" send-text --match id:1 'echo hello'
```

**With Enter (for TUI apps):** `send-text` doesn't press Enter. Send text + newline in a single call using bash ANSI-C quoting:
```bash
DISPLAY=:0 kitten @ --to "unix:$SOCK" send-text --match id:1 "${text}"$'\n'
```
The `$'\n'` embeds a literal newline byte that the TUI interprets as submit. Sending `Enter` as a separate call sends the literal word "Enter" — it won't work.

**Close a window:**
```bash
DISPLAY=:0 kitten @ --to "unix:$SOCK" close-window --match id:2
```

**Focus a window:**
```bash
DISPLAY=:0 kitten @ --to "unix:$SOCK" focus-window --match id:1
```

### Screenshots (maim)

```bash
DISPLAY=:0 maim ~/Screenshots/shot.png                # full screen
DISPLAY=:0 maim -s ~/Screenshots/shot.png             # selection (drag to capture)
DISPLAY=:0 maim -i WINDOW_ID ~/Screenshots/shot.png   # specific window
```

Find a window ID from the i3 tree or with xdotool:
```bash
DISPLAY=:0 xdotool search --name "kitty" | head -1
```

### Clipboard (xsel)

```bash
DISPLAY=:0 xsel --clipboard --output                    # read clipboard
DISPLAY=:0 xsel --clipboard --input < file.txt          # write to clipboard
DISPLAY=:0 echo "text" | xsel --clipboard --input       # pipe to clipboard
```

### Wallpaper (feh)

```bash
DISPLAY=:0 feh --bg-fill ~/wallpapers/image.png        # fill (may crop)
DISPLAY=:0 feh --bg-scale ~/wallpapers/image.png       # scale (may stretch)
DISPLAY=:0 feh --bg-center ~/wallpapers/image.png      # center (may leave gaps)
```

The i3 config uses `exec_always` to restore wallpaper on reload:
```
exec_always --no-startup-id feh --bg-fill ~/wallpapers/vestige-dark.png
```

### X11 Input Simulation (xdotool)

For apps without native remote control (not kitty, not browser):

**Send keystrokes to a window:**
```bash
DISPLAY=:0 xdotool search --name "window title" windowactivate --sync
DISPLAY=:0 xdotool type --clearmodifiers --delay 50 'text to type'
DISPLAY=:0 xdotool key Return
```

**Move/resize a window:**
```bash
DISPLAY=:0 xdotool windowmove WINDOW_ID 100 200
DISPLAY=:0 xdotool windowsize WINDOW_ID 800 600
```

**Focus a window:**
```bash
DISPLAY=:0 xdotool windowactivate WINDOW_ID
```

---

## GOTCHAS

1. **DISPLAY must be set.** Every command in this skill needs `DISPLAY=:0`. If it's missing, you'll get "Can't open display" or silent failures. Add `export DISPLAY=:0` to `~/.bashrc`.

2. **Kitty socket has a PID suffix.** The config says `listen_on unix:/tmp/kitty-ipc` but the actual socket is `/tmp/kitty-ipc-{PID}`. Always discover with `ls -t /tmp/kitty-ipc-* | head -1`. Never hardcode the path.

3. **Kitty windows need to be restarted after config changes.** If you update `kitty.conf`, existing windows keep the old config. Only new windows pick up changes. Close and reopen, or use `kitten @ launch` to open a new one.

4. **i3-msg is JSON.** Parse it — don't grep it. The tree is nested and complex. Use the Python snippets from this skill, not `grep`.

5. **`kitten @ send-text` vs `send-key`.** `send-text` sends literal text to the terminal — use it to type the text. To press the Enter key, use a separate `send-key` call: `send-key --match id:1 Enter`. Python escape sequences like `\r` insert raw control characters into the text stream, which isn't the same as a physical keypress. Two-step pattern: `send-text --match id:1 "${text}"; send-key --match id:1 Enter`.

6. **maim needs a compositor for transparency.** Without picom running, transparent windows are captured as opaque. Start picom before screenshots if you want the blur effects.

7. **xsel vs xclip.** Use `xsel`, not `xclip`. xclip has a known issue where it hangs waiting for input on some operations. xsel is more reliable for agent automation.

8. **xdotool window IDs are X11 window IDs**, not i3 container IDs. They're different numbering systems. Use `xdotool search --name` or `--class` to find windows, or extract the `window` field from the i3 tree JSON.

9. **Picom can crash silently.** If transparency stops working, check `ps aux | grep picom`. Restart with `DISPLAY=:0 picom --config ~/.config/picom/picom.conf &`.

11. **i3-msg returns success/failure as JSON.** Always check: `[{"success":true}]` means it worked. `[{"success":false}]` means the command was invalid or the target didn't exist.

12. **Scratchpad visibility: check the workspace path, not `scratchpad_state`.** The leaf window node always has `scratchpad_state='none'` even when hidden under `__i3_scratch`. The actual hidden indicator is on the parent `floating_con` node. Reliable detection: walk the tree and check if the window's ancestor chain contains a workspace named `__i3_scratch`:

    ```python
    def find_visible(node, path_contains_scratch=False):
        if node.get('type') == 'workspace' and node.get('name') == '__i3_scratch':
            path_contains_scratch = True
        w = node.get('window_properties', {}).get('class', '') or ''
        if w == 'your-class-here':
            return not path_contains_scratch
        for c in node.get('nodes', []) + node.get('floating_nodes', []):
            if find_visible(c, path_contains_scratch):
                return True
        return False
    ```

13. **i3 keybindings (`bindsym exec`) use a minimal PATH.** i3 inherits the display-manager or startx environment, not the user's interactive shell. `~/.local/bin` is NOT included by default. When a script launched from an i3 keybinding calls a tool installed via pip/pipx, prepend to PATH inside the script:
    ```bash
    export PATH="$HOME/.local/bin:$PATH"
    ```

14. **`for_window` rules only fire on window creation (map event).** They do NOT re-trigger when a window is moved or shown via `i3-msg`. This means you can safely toggle a window in/out of scratchpad with `i3-msg` even if a `for_window` rule exists for that class.

---

## RECIPES

### Open a kitty window, run a command, read the output

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)

# Launch htop in a new kitty window
DISPLAY=:0 kitten @ --to "unix:$SOCK" launch --type=window htop
sleep 2

# Read what it's showing
DISPLAY=:0 kitten @ --to "unix:$SOCK" get-text --match id:2

# Close it
DISPLAY=:0 kitten @ --to "unix:$SOCK" close-window --match id:2
```

### Send a command to the user's kitty terminal

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)

# Find the window running tmux (check the title)
DISPLAY=:0 kitten @ --to "unix:$SOCK" ls | python3 -c "
import json, sys
for os_win in json.load(sys.stdin):
    for tab in os_win.get('tabs', []):
        for win in tab.get('windows', []):
            if 'tmux' in win.get('title', ''):
                print(win['id'])
" 

# Send a command to it (use the window ID from above)
DISPLAY=:0 kitten @ --to "unix:$SOCK" send-text --match id:1 'echo "from agent"'
```

### Take a screenshot and analyze it

```bash
DISPLAY=:0 maim /tmp/desktop.png
# Then use vision_analyze(image_url='/tmp/desktop.png', question='...')
```

### Move a window to a specific workspace

```bash
# By class
DISPLAY=:0 i3-msg '[class="Chromium"] move container to workspace 5'

# By title
DISPLAY=:0 i3-msg '[title="htop"] move container to workspace 9'
```

### Open chromium to a specific URL

```bash
DISPLAY=:0 i3-msg 'workspace 5'
DISPLAY=:0 chromium --remote-debugging-port=9222 'https://example.com' &
sleep 3
# Verify CDP is active
curl -s http://localhost:9222/json/version
```

### Copy a file's contents to the clipboard

```bash
cat /path/to/file.txt | DISPLAY=:0 xsel --clipboard --input
```

### Tile two kitty windows side by side

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)

# Kill existing layout
DISPLAY=:0 i3-msg '[class="kitty"] kill'

# Open first kitty (takes full screen)
DISPLAY=:0 i3-msg exec kitty
sleep 2

# Open second kitty (i3 auto-splits)
DISPLAY=:0 i3-msg exec kitty
sleep 2

# Both are now side by side
```

### Restore desktop state after reboot

The i3 config's `exec_always` section handles this automatically:
- Picom starts (compositor)
- feh restores the wallpaper
- kitty launches
- Chromium launches with CDP

If anything fails, restart manually:
```bash
DISPLAY=:0 picom --config ~/.config/picom/picom.conf &
DISPLAY=:0 feh --bg-fill ~/wallpapers/vestige-dark.png
DISPLAY=:0 i3-msg exec kitty
DISPLAY=:0 chromium --remote-debugging-port=9222 --no-first-run --no-default-browser-check &
```
