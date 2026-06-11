# Shi — A Desktop for Humans and Agents

A CLI-first, Vi-driven desktop environment for Debian, designed so both you and an AI agent can see, control, and automate every layer.

**Shi (勢)** — from Sun Tzu's *Art of War*: the strategic advantage stored in favorable positioning. Like a drawn crossbow, the right arrangement of tools creates potential that can be released at the decisive moment. This desktop is that arrangement.

---

## What You Get

- **i3** tiling window manager — Vi-style navigation, scriptable via `i3-msg`
- **Kitty** terminal — GPU-accelerated with remote control (`kitten @` protocol)
- **Picom** compositor — transparency, blur, shadows
- **Chromium** with CDP — browser automation from the command line
- **Tmux** integration — terminal multiplexing with shared Vi keys
- **Agent TUI** — Quake-style dropdown (`$mod+grave`) with Shi preloaded
- **Rofi agent prompt** — one-shot questions via `$mod+a`, routes to TUI or fallback
- **Everything CLI-controllable** — the agent doesn't need to fake mouse clicks

## What You Need

- Debian 12+ (tested on Trixie/13)
- A connected display
- sudo access
- ~30 minutes

---

## Philosophy

This isn't about making your desktop look pretty (though it does). It's about building a workspace where both you and an AI agent can operate — moving windows, launching programs, reading screens, taking screenshots — all through CLI tools.

Every tool here has a command-line interface. Every keybinding follows Vi conventions. The agent talks to i3, kitty, and Chromium through their native IPC protocols.

**Design principles:**

1. **CLI-first** — if you can't control it from the terminal, it doesn't belong here
2. **Vi keys everywhere** — `h/j/k/l` for navigation in i3, tmux, vim, resize mode
3. **Agent-transparent** — the agent can see, control, and automate every layer
4. **Minimal** — nothing heavy, nothing that needs a full desktop environment
5. **Persistent** — everything auto-starts on login, survives reboots

---

## Architecture

```
┌───────────────────────────────────────────────┐
│                     i3                        │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐  │
│  │   kitty    │ │   kitty    │ │ chromium  │  │
│  │  + tmux    │ │  + bash    │ │  (CDP)    │  │
│  └────────────┘ └────────────┘ └───────────┘  │
│  ┌─────────────────────────────────────────┐  │
│  │            i3bar (top)                  │  │
│  └─────────────────────────────────────────┘  │
├───────────────────────────────────────────────┤
│  Picom compositor  │  feh (wallpaper)         │
└───────────────────────────────────────────────┘
```

**Control stack:**

| Layer | CLI Tool | Agent Access |
|-------|----------|--------------|
| Window manager | `i3-msg` | `DISPLAY=:0 i3-msg` |
| Terminal | `kitten @` | Via Unix socket |
| Agent TUI | `$mod+grave` | Quake dropdown, relaunches if killed |
| Agent prompt | `$mod+a` | Rofi → kitty IPC or `hermes chat -q` |
| Browser | CDP (port 9222) | `browser_*` tools |
| Screenshots | `maim` | `DISPLAY=:0 maim` |
| Keyboard/mouse | `xdotool` | `DISPLAY=:0 xdotool` |

---

## Installation

### 1. Core Packages

```bash
sudo apt-get install -y \
  i3 i3status i3lock rofi \
  kitty \
  picom \
  feh \
  maim xdotool xsel \\
  vim-gtk3 \\
  chromium lightdm
```

**Why these:**

- **i3** — tiling WM, scriptable via `i3-msg`, Vi-native navigation. Chosen over Sway (X11 ecosystem is more mature for agent tooling) and Awesome/Xmonad (simpler config, better CLI surface).
- **kitty** — GPU-accelerated terminal with a remote control protocol. This is the killer feature — `kitten @` lets the agent send commands, read terminal contents, and manage windows without faking keystrokes. Alacritty and WezTerm don't have this.
- **picom** — compositor for transparency, shadows, blur. The successor to Compton (dead) and xcompmgr (too minimal). Without picom, kitty's `background_opacity` is silently ignored.
- **feh** — lightweight wallpaper setter. One command, no dependencies.
- **maim** — modern screenshot tool. Replaces scrot (unmaintained) and ImageMagick's import (overkill).
- **xdotool** — X11 automation for non-kitty apps. Send keystrokes, move windows, simulate input.
- **xsel** — clipboard access from the terminal. Required by tmux-yank for system clipboard integration. Also gives the agent read/write access to the clipboard via `DISPLAY=:0 xsel`.
- **vim-gtk3** — Vim with GTK3 GUI support, which enables `+clipboard`. This lets Vim share the system clipboard via `set clipboard=unnamedplus`. Plain `vim` on Debian doesn't have clipboard support compiled in.
- **rofi** — application launcher and window switcher. Replaces dmenu with a full GUI: app launcher with icons (`$mod+d`), window switcher (`$mod+Tab`), and command runner (`$mod+Shift+d`). Fuzzy search, Vi navigation, fully themeable. This is the single biggest quality-of-life upgrade over dmenu.
- **chromium** — browser with Chrome DevTools Protocol (CDP) for agent automation. The agent navigates, clicks, fills forms, and reads pages programmatically.
- **lightdm** — display manager with autologin support.

### 2. Display Manager

Configure LightDM for autologin into i3:

```bash
# Add user to autologin group (required for LightDM autologin)
sudo groupadd -r autologin
sudo gpasswd -a $USER autologin

# Configure LightDM
sudo tee -a /etc/lightdm/lightdm.conf << 'EOF'

[Seat:*]
user-session=i3
autologin-user=yourusername
EOF

sudo systemctl enable lightdm
```

### 3. Install the Configs

```bash
git clone https://github.com/m4dni5/shi-env.git
cd shi-env
./install.sh
```

The install script handles everything:

- **Standalone configs** (i3, kitty, picom, i3status) are copied to `~/.config/` — these are full configs that replace the defaults. Existing configs are backed up to `.bak` before overwriting.
- **Additive configs** (bash, vim, tmux) contain only the shi-specific additions, wrapped in marker comments.
  - **Bash**: additions are appended to your existing `~/.bashrc` (idempotent — skips if already present).
  - **Vim**: uses `" --- SHI BEGIN ---` / `" --- SHI END ---` markers (`"` is Vim's comment character). Existing file is backed up to `.bak`.
  - **Tmux**: uses `# --- SHI BEGIN ---` / `# --- SHI END ---` markers. Existing file is backed up to `.bak`.

**⚠️ Back up your existing configs first** if you have customizations you want to keep. The script creates `.bak` copies, but a manual backup is safer.

**Uninstall:** For bash and tmux, remove the block between `# --- SHI BEGIN ---` and `# --- SHI END ---`. For vim, remove the block between `" --- SHI BEGIN ---` and `" --- SHI END ---`. Restore from the `.bak` files if needed. For standalone configs (i3, kitty, picom, i3status), restore from `~/.config/*/config.bak` or `~/.config/kitty/kitty.conf.bak`.

### 4. Agent Integration (Hermes)

If you're running Hermes Agent, Shi gives you two surfaces:

**Quake TUI dropdown** (`$mod+grave`) — A floating kitty window running `hermes --tui -c -s i3-desktop,tmux` (class `shi-tui`, title `Shi`). Starts on login, parked in the scratchpad. Press `$mod+grave` to summon, same key to dismiss. If the window was killed, the toggle script relaunches it automatically. The `-c` flag continues your last session, so the conversation persists across toggles. Skills `i3-desktop` and `tmux` are preloaded so the agent knows how to drive the desktop.

**Rofi one-shot** (`$mod+a`) — Type a question in rofi. If the TUI is running, the prompt is sent directly into it (kitty IPC) and the TUI is summoned. If the TUI isn't running, falls back to `hermes chat -q` and displays the response in rofi.

Wire up X11 access and browser control:

```bash
# Let agent tools access X11
echo 'export DISPLAY=:0' >> ~/.bashrc
xhost +local:

# Set browser CDP in Hermes config
hermes config set browser.cdp_url "http://localhost:9222"
```

---

## Config Walkthrough

### i3 — Window Manager

**File:** `configs/i3/config`

The i3 config is the backbone. Every decision here serves the CLI-first principle.

**Why Super (Mod4) and not Alt:** Alt conflicts with terminal applications — tmux, vim, bash, and most CLI tools all use Alt for their own bindings. Super sits unused under the left thumb.

**Colors:** Five variables control the entire theme:

```
set $bg       #1a1a2e    # deep navy
set $fg       #c8c8d4    # muted silver
set $accent   #c9a227    # amber gold
set $urgent   #c94427    # rust red
set $dim      #4a4a5e    # grey
```

Change these five values and the entire desktop rethemes — i3 bar, rofi, window decorations.

**Navigation (Vi-style):**

| Key | Action |
|-----|--------|
| `$mod+h/j/k/l` | Focus left/down/up/right |
| `$mod+Shift+h/j/k/l` | Move window |
| `$mod+1-0` | Switch workspace |
| `$mod+Shift+1-0` | Move window to workspace |

**Layout:**

| Key | Action |
|-----|--------|
| `$mod+v` | Split horizontal |
| `$mod+Shift+v` | Split vertical |
| `$mod+b` | Stacking layout |
| `$mod+w` | Tabbed layout |
| `$mod+e` | Toggle split |
| `$mod+f` | Fullscreen |

**Floating:**

| Key | Action |
|-----|--------|
| `$mod+Shift+Space` | Toggle float |
| `$mod+Space` | Focus toggle (tiled ↔ floating) |
| `$mod+left-drag` | Move floating window |
| `$mod+right-drag` | Resize floating window |

The `floating_modifier $mod` directive enables mouse-based move/resize on floating windows. Without it, you can only resize via keyboard.

**Resize mode** (`$mod+r` to enter):

| Key | Action |
|-----|--------|
| `h/j/k/l` | 10px adjustments |
| `Shift+h/j/k/l` | 50px jumps |
| `Arrow keys` | 10px adjustments |
| `Enter` / `Escape` | Exit resize mode |

**Window decorations:** 2px pixel borders, no title bars. Minimal and clean.

**Bar:** Top-positioned i3status with the theme colors. `i3status` feeds system metrics — disk, memory, CPU, load, time. Uses plain text labels instead of icon fonts for universal compatibility.

**Autostart:** Picom (compositor), feh (wallpaper), kitty (terminal), and Chromium (browser with CDP) all launch automatically on login.

**Screenshots:**

| Key | Action |
|-----|--------|
| `Print` | Full screen screenshot → `~/Screenshots/` |
| `$mod+Print` | Selection mode (drag to capture region) |

**Agent surfaces:**

| Key | Surface | What happens |
|-----|---------|-------------|
| `$mod+grave` | Quake TUI | Toggles Shi TUI from scratchpad. Relaunches if killed. `hermes --tui -c -s i3-desktop,tmux` — continues last session, preloads desktop skills. |
| `$mod+a` | Rofi one-shot | Prompt in rofi. If TUI is running, sends prompt into it via kitty IPC and summons the window. Otherwise falls back to `hermes chat -q`. |

The TUI starts on login (kitty with class `shi-tui`, parked in scratchpad). 1400×800, centered, 92% opacity — visually distinct from regular terminals. `confirm_os_window_close=0` prevents kitty's exit confirmation dialog. The toggle script (`shi-toggle.sh`) checks if the window is visible, in the scratchpad, or gone — and acts accordingly. If the window was killed, it relaunches.

**File:** `configs/i3/rofi-agent.sh`

The rofi one-shot script checks for a running kitty IPC socket, looks for a window titled "Shi", and if found, sends the prompt text directly into it. If the TUI isn't running, it falls back to `hermes chat -q` and displays the response in a read-only rofi window.

### Kitty — Terminal

**File:** `configs/kitty/kitty.conf`

Kitty is chosen over alacritty and urxvt for one reason: **remote control**. The `kitten @` protocol lets the agent send commands, read terminal contents, and manage windows without faking keystrokes.

**Key settings:**

```
allow_remote_control yes
listen_on unix:/tmp/kitty-ipc
```

The socket gets a PID suffix at runtime (`/tmp/kitty-ipc-{PID}`). Discover it with:

```bash
ls -t /tmp/kitty-ipc-* | head -1
```

**Agent commands:**

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)

kitten @ --to unix:$SOCK ls                            # list windows/tabs
kitten @ --to unix:$SOCK send-text --match id:1 'cmd'  # type into window
kitten @ --to unix:$SOCK launch --type=window htop      # open new window
kitten @ --to unix:$SOCK get-text --match id:1          # read terminal contents
kitten @ --to unix:$SOCK close-window --match id:2      # close window
kitten @ --to unix:$SOCK focus-window --match id:1      # switch focus
```

**Theme:** Mountain Twilight — deep navy backgrounds (`#1a1a2e`), muted silver text, amber gold accents. Kitty runs at full opacity; picom handles all transparency (focused at 90%, unfocused at 80%) with blur behind.

**Cursor note:** kitty 0.41.1 renamed `cursor_color` to `cursor`. If you're on an older version, use `cursor_color` instead.

### Picom — Compositor

**File:** `configs/picom/picom.conf`

Picom adds the visual layer: transparency, blur, shadows, fading. Picom is the single source of truth for window opacity — kitty runs at `background_opacity 1.0` so the two layers don't compound.

**Effects:**

- **Transparency:** Focused kitty at 90%, unfocused at 80%. Chromium stays at 100%.
- **Blur:** `dual_kawase` at strength 3 — frosted glass behind transparent windows. Keeps text readable even with a busy wallpaper.
- **Shadows:** 12px radius, 0.6 opacity — subtle depth without being distracting.
- **Fading:** 0.03 step transitions — smooth but not slow.

**Backend:** `glx` with vsync. If you get screen tearing, try switching to `xrender`.

### Rofi — Application Launcher

**File:** `configs/rofi/config.rasi`

Rofi replaces dmenu with a full GUI launcher. Three modes, all accessible via i3 keybindings:

| Key | Mode | What it does |
|-----|------|-------------|
| `$mod+d` | `drun` | App launcher with icons and descriptions |
| `$mod+Tab` | `window` | Switch between open windows |
| `$mod+Shift+d` | `run` | Raw command runner (like dmenu) |

**Theme:** Mountain Twilight palette — matches i3 and kitty. Amber gold selection highlight on deep navy background. 600px fixed width, 10 visible results, Papirus icon theme.

**Why rofi over dmenu:** Fuzzy search, icon support, Vi-style navigation (arrow keys or type to filter), window switching mode, and full theming. The `$mod+d` → `$mod+Tab` → `$mod+Shift+d` triad covers app launching, window switching, and raw command execution without leaving the keyboard.

**CLI usage (agent):**
```bash
# Launch an app
DISPLAY=:0 rofi -show drun -show-icons

# Switch to a window by name
DISPLAY=:0 rofi -show window -filter "kitty"

# Run a raw command
DISPLAY=:0 rofi -show run
```

### Tmux — Terminal Multiplexer

**File:** `configs/tmux/tmux.conf`

Tmux and i3 serve different purposes but use the same navigation keys. This is intentional — muscle memory transfers.

**i3 manages windows across the desktop.** Tmux manages terminal sessions within a single window.

**Navigation — same keys as i3, no prefix needed:**

| Key | Action |
|-----|--------|
| `Alt+h/j/k/l` | Switch panes |
| `Ctrl+b %` | Split horizontal |
| `Ctrl+b "` | Split vertical |
| `Ctrl+b c` | New window |
| `Ctrl+b n/p` | Next/prev window |
| `Ctrl+b [` | Copy mode (Vi-style) |
| `Ctrl+b z` | Zoom pane (fullscreen toggle) |

**Vi mode:** `set-window-option -g mode-keys vi` — enables Vi-style copy mode. `Space` starts selection, `h/j/k/l` navigates, `Enter` copies.

**Mouse:** Enabled for pane resizing and scrollback. The agent uses tmux's `send-keys` and `capture-pane` for programmatic access.

**Plugins (via TPM):**
- `tmux-yank` — sync clipboard with system
- `tmux-logging` — log pane output to file
- `tmux-tokyo-night` — night variant

### Vim — Editor

**File:** `configs/vim/vimrc`

Minimal config focused on code editing:

```vim
set nocompatible
filetype on
filetype indent on
syntax on
set number
set autoindent expandtab tabstop=4 shiftwidth=4
set clipboard=unnamedplus
```

This is a starting point. The important settings are `expandtab` (spaces, not tabs), `shiftwidth=4` (standard indent), and `clipboard=unnamedplus` (system clipboard integration — yank in vim, paste anywhere). Requires `vim-gtk3` — the plain `vim` package on Debian doesn't compile with clipboard support.

### Bash — Shell

**File:** `configs/bash/bashrc`

Shi additions appended to your existing `.bashrc`:

```bash
export DISPLAY=:0
export EDITOR=vim
export VISUAL=$EDITOR
set -o vi
```

`DISPLAY=:0` lets any new terminal shell reach the X server. Without it, tools like `i3-msg`, `xdotool`, and `kitten @` can't find the display. `set -o vi` enables Vi-mode keybindings in bash.

---

## Agent Control Reference

Quick reference for everything the agent can do.

### i3 Window Manager

```bash
DISPLAY=:0 i3-msg reload                     # reload config
DISPLAY=:0 i3-msg 'workspace 2'              # switch workspace
DISPLAY=:0 i3-msg '[class="kitty"] kill'     # close all kitty windows
DISPLAY=:0 i3-msg -t get_tree                # full window tree (JSON)
DISPLAY=:0 i3-msg -t get_outputs             # monitor info
```

### Kitty Terminal

```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
kitten @ --to unix:$SOCK ls                  # list all windows
kitten @ --to unix:$SOCK send-text --match id:1 'echo hello\n'
kitten @ --to unix:$SOCK get-text --match id:1
kitten @ --to unix:$SOCK launch --type=window htop
kitten @ --to unix:$SOCK close-window --match id:2
```

### Browser (CDP)

```bash
curl -s http://localhost:9222/json/version    # verify CDP is running
curl -s http://localhost:9222/json            # list open tabs
# Or use Hermes browser_* tools directly
```

### Clipboard

```bash
DISPLAY=:0 xsel --clipboard --output          # read clipboard
DISPLAY=:0 xsel --clipboard --input < file.txt # write to clipboard
DISPLAY=:0 echo "text" | xsel --clipboard      # pipe to clipboard
```

### Screenshots

```bash
DISPLAY=:0 maim ~/shot.png                   # full screen
DISPLAY=:0 maim -s ~/shot.png                # selection (drag to capture)
DISPLAY=:0 maim -i WINDOW_ID ~/shot.png      # specific window
```

### Tmux

```bash
tmux list-panes -a                           # list all panes
tmux capture-pane -p -J -t %0 -S -100       # capture pane output
tmux send-keys -t %0 'command' Enter        # send command to pane
tmux new-session -d -s build                 # new named session
```

---

## Keyboard Reference Card

### Global (i3)

| Key | Action |
|-----|--------|
| `$mod+Return` | Open kitty |
| `$mod+q` | Close window |
| `$mod+d` | rofi app launcher |
| `$mod+Tab` | rofi window switcher |
| `$mod+Shift+d` | rofi command runner |
| `$mod+a` | Ask agent (rofi one-shot) |
| `$mod+grave` | Agent TUI toggle (Quake, auto-relaunch) |
| `$mod+h/j/k/l` | Focus left/down/up/right |
| `$mod+Shift+h/j/k/l` | Move window |
| `$mod+1-0` | Switch workspace |
| `$mod+Shift+1-0` | Move to workspace |
| `$mod+v` | Split horizontal |
| `$mod+Shift+v` | Split vertical |
| `$mod+f` | Fullscreen |
| `$mod+Shift+Space` | Toggle float |
| `$mod+Space` | Focus toggle |
| `$mod+r` | Enter resize mode |
| `$mod+Shift+r` | Reload config |
| `$mod+Shift+e` | Exit i3 |
| `Print` | Screenshot |
| `$mod+Print` | Screenshot selection |

### Inside Terminal (Tmux)

| Key | Action |
|-----|--------|
| `Alt+h/j/k/l` | Switch pane |
| `Ctrl+b %` | Split horizontal |
| `Ctrl+b "` | Split vertical |
| `Ctrl+b c` | New window |
| `Ctrl+b n/p` | Next/prev window |
| `Ctrl+b [` | Copy mode (Vi) |
| `Ctrl+b z` | Zoom pane |

### Resize Mode (i3)

| Key | Action |
|-----|--------|
| `h/j/k/l` | 10px adjustment |
| `Shift+h/j/k/l` | 50px jump |
| `Arrow keys` | 10px adjustment |
| `Enter` / `Escape` | Exit mode |

---

## Troubleshooting

### i3: "Unable to find configuration file"

No config file exists. Copy from this repo:

```bash
cp configs/i3/config ~/.config/i3/config
```

### LightDM: Login loop

`/var/run/utmpx` missing (common on minimal/container installs):

```bash
sudo touch /var/run/utmpx && sudo chmod 644 /var/run/utmpx
```

### Kitty: Config not loading

`cursor_color` was renamed to `cursor` in kitty 0.41.1. Use `cursor` in kitty.conf.

### Kitty: Transparency not working

No compositor running. Picom owns all window transparency — kitty's `background_opacity` is set to `1.0` (opaque) so the two layers don't compound. If you want to adjust transparency, edit picom's `opacity-rule` in `configs/picom/picom.conf`, not kitty.conf.

### i3status: Broken icons in bar

Nerd Font glyphs require a patched font. This config uses plain text labels instead. If you see boxes or question marks, switch to the plain labels in `configs/i3status/config`.

### Browser tools: "Could not connect"

Chromium needs to run with CDP enabled:

```bash
chromium --remote-debugging-port=9222
```

Then set in Hermes:

```bash
hermes config set browser.cdp_url "http://localhost:9222"
```

### Agent can't access X11

The terminal session needs the `DISPLAY` variable:

```bash
echo 'export DISPLAY=:0' >> ~/.bashrc
xhost +local:
```

---

## Skills

The `skills/` directory contains Hermes Agent skills — procedural knowledge for desktop automation. These are loaded on demand, not all at once.

### i3 Desktop (`skills/i3-desktop/`)

Everything between the agent and the desktop: i3-msg window management, kitty remote control (`kitten @`), maim screenshots, xsel clipboard, feh wallpaper, and xdotool input simulation.

Load when: moving windows, launching apps, capturing the screen, reading the clipboard, or controlling kitty programmatically.

### Tmux (`skills/tmux/`)

Terminal multiplexer operations: send-keys, capture-pane, copy mode, session management, coordinate long-running work across panes.

Load when: working inside terminal sessions, watching builds, extracting text from scrollback, or coordinating parallel work.

### Installing Skills

```bash
# Copy to Hermes
cp -r skills/i3-desktop ~/.hermes/skills/
cp -r skills/tmux ~/.hermes/skills/

# Or use the install script (does this automatically)
./install.sh
```

---

## Recommended Tools

Not included in the core install, but worth adding. These all follow the CLI-first, Vi-key philosophy:

```bash
sudo apt-get install -y fzf ripgrep fd-find dunst ranger htop
```

| Tool | What it does | Why it fits |
|------|-------------|-------------|
| **fzf** | Fuzzy finder for files, commands, history | The single biggest CLI productivity multiplier. `Ctrl+r` for history, `Ctrl+t` for files. Agent can use it for interactive discovery. |
| **ripgrep** (`rg`) | Fast grep replacement | 10-100x faster than grep on large codebases. Agent's `search_files` tool uses it internally. |
| **fd** | Fast `find` replacement | Cleaner syntax than `find`, respects `.gitignore`. Agent's file discovery benefits from it. |
| **dunst** | Notification daemon | i3 doesn't have one. Without it, system notifications, cron alerts, and battery warnings are silently dropped. Lightweight, CLI-configurable via `dunstctl`. |
| **ranger** | Terminal file manager with Vi keys | Better than `ls`/`cd`/`cat` for browsing the filesystem. Image previews with kitty's icat protocol. |
| **htop** | Process monitor | Interactive `top` replacement with Vi-style navigation and tree view. |
| **betterlockscreen** | Lock screen with blurred wallpaper | Wraps i3lock with the wallpaper blurred. Requires `i3lock`. Install from GitHub — not in Debian repos. |

### Notifications (dunst)

After installing dunst, add it to i3 autostart:

```
exec --no-startup-id dunst &
```

Test with:

```bash
notify-send "Shi" "Desktop notifications working"
```

### Lock Screen (betterlockscreen)

```bash
# Install from GitHub (not in Debian repos)
git clone https://github.com/betterlockscreen/betterlockscreen.git
cd betterlockscreen
sudo cp betterlockscreen /usr/local/bin/

# Generate blurred wallpaper variants
betterlockscreen -u ~/wallpapers/vestige-dark.png

# Lock
betterlockscreen -l
```

Add to i3 config:

```
bindsym $mod+x exec --no-startup-id betterlockscreen -l
```

---

## Customization

### Theming

All colors are defined as five variables at the top of the i3 config. Change these and everything follows:

```
set $bg       #1a1a2e    # background
set $fg       #c8c8d4    # foreground text
set $accent   #c9a227    # highlights and focus
set $urgent   #c94427    # alerts
set $dim      #4a4a5e    # inactive elements
```

Match the kitty theme to the same palette in `kitty.conf`.

### Gaps

If you install `i3-gaps`, uncomment in the i3 config:

```
gaps inner 8
gaps outer 2
```

### Wallpaper

Replace `~/wallpapers/vestige-dark.png` and update the feh command in i3 config:

```
exec_always --no-startup-id feh --bg-fill ~/wallpapers/your-wallpaper.png
```

Generate wallpapers with AI:

```bash
hermes chat -q "Generate a dark minimalist landscape wallpaper"
```

---

## Contributing

Config files in `configs/` are the source of truth. The README explains why.

If you find a better way to do something, a missing step, or a broken command — open an issue or PR.

---

## License

MIT.
