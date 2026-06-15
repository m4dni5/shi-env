# Shi — A Desktop for Humans and Agents

A CLI-first, Vi-driven desktop environment for Debian, designed so both you and an AI agent can see, control, and automate every layer.

**Shi (勢)** — from Sun Tzu's *Art of War*: the strategic advantage stored in favorable positioning. Like a drawn crossbow, the right arrangement of tools creates potential that can be released at the decisive moment. This desktop is that arrangement.

---

## What You Get

- **Sway** tiling compositor — i3-compatible config, Vi-style navigation, scriptable via `swaymsg`
- **Kitty** terminal — GPU-accelerated with remote control (`kitten @` protocol)
- **Waybar** status bar — CSS-themed, same data as i3status (disk, memory, CPU, load, time)
- **Chromium** with CDP — browser automation from the command line
- **Tmux** integration — terminal multiplexing with shared Vi keys
- **Agent TUI** — Quake-style dropdown (`$mod+grave`), preloaded with skills, relaunches if killed
- **Everything CLI-controllable** — the agent doesn't need to fake mouse clicks

---

## Philosophy

This isn't about making your desktop look pretty (though it does). It's about building a workspace where both you and an AI agent can operate — moving windows, launching programs, reading screens, taking screenshots — all through CLI tools.

Every tool here has a command-line interface. Every keybinding follows Vi conventions. The agent talks to sway, kitty, and Chromium through their native IPC protocols.

**Design principles:**

1. **CLI-first** — if you can't control it from the terminal, it doesn't belong here
2. **Vi keys everywhere** — `h/j/k/l` for navigation in sway, tmux, vim, resize mode
3. **Agent-transparent** — the agent can see, control, and automate every layer
4. **Minimal** — nothing heavy, nothing that needs a full desktop environment
5. **Persistent** — everything auto-starts on login, survives reboots

---

## Architecture

```
┌───────────────────────────────────────────────┐
│                     Sway                      │
│  ┌────────────┐ ┌────────────┐ ┌───────────┐  │
│  │   kitty    │ │   kitty    │ │ chromium  │  │
│  │  + tmux    │ │  + bash    │ │  (CDP)    │  │
│  └────────────┘ └────────────┘ └───────────┘  │
│  ┌─────────────────────────────────────────┐  │
│  │           waybar (top)                  │  │
│  └─────────────────────────────────────────┘  │
├───────────────────────────────────────────────┤
│  Sway compositor (built-in) │ swaybg (wall)   │
└───────────────────────────────────────────────┘
```

**Control stack:**

| Layer | CLI Tool | Agent Access |
|-------|----------|--------------|
| Compositor | `swaymsg` | `swaymsg` (no DISPLAY needed) |
| Terminal | `kitten @` | Via Unix socket |
| Agent TUI | `$mod+grave` | Quake dropdown, auto-relaunches |
| Browser | CDP (port 9222) | `browser_*` tools |
| Screenshots | `grim` + `slurp` | `grim`, `slurp` for selection |
| Clipboard | `wl-copy` / `wl-paste` | `wl-copy`, `wl-paste` |
| Keyboard/mouse | `ydotool` / `wtype` | `ydotool` (daemon) or `wtype` |

---

## Installation

Debian 12+ / Parrot OS Security. You need a connected display and sudo access.

### Core Packages

```bash
sudo apt-get install -y \
  sway swaybg \
  waybar \
  grim slurp \
  wl-clipboard \
  ydotool wtype \
  rofi \
  kitty \
  vim-gtk3 \
  chromium \
  jq \
  xdg-desktop-portal-wlr \
  swaylock \
  swayidle
```

**Why these:**

- **Sway** — i3-compatible Wayland compositor. Same config syntax as i3, native Wayland, built-in compositing (no picom needed), built-in gaps. The `swaymsg` IPC protocol is nearly identical to `i3-msg`.
- **kitty** — GPU-accelerated terminal with a remote control protocol. `kitten @` lets the agent send commands, read terminal contents, and manage windows without faking keystrokes. Works natively on Wayland.
- **waybar** — status bar for Wayland compositors. Replaces i3status with CSS theming, more modules, and native Wayland support. Config is `config.jsonc` (waybar 0.12.0+).
- **grim** + **slurp** — screenshots on Wayland. `grim` captures the screen, `slurp` provides interactive region selection. Replaces `maim` (X11-only).
- **wl-clipboard** — clipboard access on Wayland. `wl-copy` and `wl-paste` replace `xsel`/`xclip` with a cleaner API.
- **ydotool** — input simulation on Wayland. Replaces `xdotool` (X11-only). Requires `ydotoold` daemon (started automatically by sway config).
- **wtype** — lightweight keyboard injection on Wayland. Simpler than ydotool for keyboard-only tasks. No daemon needed.
- **rofi** — application launcher. Works on Wayland (use `rofi-wayland` fork if available in your repos). Same config as the X11 version.
- **chromium** — browser with CDP for agent automation. Runs identically on Wayland.
- **jq** — JSON processor. Used by the Quake TUI toggle script and window switcher to parse sway's tree output.
- **vim-gtk3** — Vim with clipboard support. Detects Wayland automatically via `wl-clipboard`.
- **xdg-desktop-portal-wlr** — Wayland portal backend for Sway/wlroots. Provides screenshot and screencast portals. Without it, `xdg-desktop-portal` falls back to GTK/KDE backends (which timeout in pure Sway) and waybar crashes with a segfault on startup. The install script also creates `~/.config/xdg-desktop-portal/portals.conf` to set the correct backend priority.
- **swaylock** — screen locker for Wayland. Mountain Twilight theme in `configs/swaylock/config`. `$mod+Escape` to lock immediately; auto-locks after 5 min idle with 10s grace period.
- **swayidle** — idle daemon for Sway. Triggers auto-lock after 5 min and DPMS off after 10 min. Configured inline in sway config.

### Starting Sway

Sway starts from a TTY login. No display manager needed (though one works too):

```bash
# Option 1: Manual start from TTY
# Log in on a TTY, then:
sway

# Option 2: Auto-start on TTY login (add to ~/.bash_profile or ~/.zprofile)
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec sway
fi

# Option 3: Display manager (greetd, SDDM, etc.)
# Configure for sway session — see your DM's docs
```

### Login Screen (greetd + tuigreet)

Shi uses [greetd](https://git.sr.ht/~kennylevinsen/greetd) with [tuigreet](https://github.com/apognu/tuigreet) as the login manager. The theme matches the Mountain Twilight palette:

```
container=#1a1a2e  (deep navy background)
border=#4a4a5e     (dim grey border)
text=#c8c8d4       (muted silver text)
title=#c9a227      (amber gold title)
time=#c9a227       (amber gold clock)
greet=#c9a227      (amber gold "Shi" greeting)
prompt=#4a4a5e     (dim grey prompt labels)
input=#c8c8d4      (silver user input)
action=#c8c8d4     (silver status bar)
button=#c9a227     (amber gold pill buttons — REVERSED)
```

The config lives at `/etc/greetd/config.toml`. A template is at `configs/greetd/config.toml` in this repo. The install script checks if the theme matches and warns if it doesn't.

### Install the Configs

```bash
git clone https://github.com/m4dni5/shi-env.git
cd shi-env
./install.sh
```

The install script handles everything:

- **Standalone configs** (sway, kitty, waybar) are copied to `~/.config/` — these are full configs that replace the defaults. Existing configs are backed up to `.bak` before overwriting.
- **Additive configs** (bash, vim, tmux) contain only the shi-specific additions, wrapped in marker comments.
  - **Bash**: additions are appended to your existing `~/.bashrc` (idempotent — skips if already present). If upgrading from X11, the old `DISPLAY=:0` line is automatically removed.
  - **Vim**: uses `" --- SHI BEGIN ---` / `" --- SHI END ---` markers (`"` is Vim's comment character). Existing file is backed up to `.bak`.
  - **Tmux**: uses `# --- SHI BEGIN ---` / `# --- SHI END ---` markers. Existing file is backed up to `.bak`.

**⚠️ Back up your existing configs first** if you have customizations you want to keep. The script creates `.bak` copies, but a manual backup is safer.

### Agent Integration (Hermes)

If you're running Hermes Agent, Shi gives you a Quake-style TUI dropdown (`$mod+grave`) — a floating kitty window running `hermes --tui -c -s sway-desktop,tmux` (class `shi-tui`). Starts on login, parked in the scratchpad. Press `$mod+grave` to summon, same key to dismiss. If the window was killed, the toggle script relaunches it automatically. The `-c` flag continues your last session, so the conversation persists. Skills `sway-desktop` and `tmux` are preloaded so the agent knows how to drive the desktop.

Wire up browser control:

```bash
hermes config set browser.cdp_url "http://localhost:9222"
```

---

## Config Walkthrough

### Sway — Compositor/Window Manager

**File:** `configs/sway/config`

The sway config is the backbone. Sway is i3-compatible in config syntax — if you know i3, you know sway. Every decision here serves the CLI-first principle.

**Why Super (Mod4) and not Alt:** Alt conflicts with terminal applications — tmux, vim, bash, and most CLI tools all use Alt for their own bindings. Super sits unused under the left thumb.

**Colors:** Five variables control the entire theme:

```
set $bg       #1a1a2e    # deep navy
set $fg       #c8c8d4    # muted silver
set $accent   #c9a227    # amber gold
set $urgent   #c94427    # rust red
set $dim      #4a4a5e    # grey
```

Change these five values and the entire desktop rethemes — sway bar, rofi, waybar, window decorations.

**Window decorations:** 2px pixel borders, no title bars. Minimal and clean.

**Gaps:** Built into sway (no i3-gaps package needed). 4px inner gaps, 0px outer.

**Bar:** Top-positioned waybar with the theme colors. CSS-themed — edit `configs/waybar/style.css` to customize. Shows disk, memory, CPU, load, and time.

**Transparency:** Sway handles compositing natively — no picom needed. Focused kitty at 90% opacity via `for_window` rule. Kitty's `background_opacity` works natively on Wayland.

**Autostart:** swaybg (wallpaper), kitty (terminal), Chromium (browser with CDP), ydotoold (input daemon) all launch automatically on login.

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

**Theme:** Mountain Twilight — deep navy backgrounds (`#1a1a2e`), muted silver text, amber gold accents. Kitty runs at 90% opacity via sway's `for_window` rule.

**Cursor note:** kitty 0.41.1 renamed `cursor_color` to `cursor`. If you're on an older version, use `cursor_color` instead.

### Waybar — Status Bar

**Files:** `configs/waybar/config.jsonc` + `configs/waybar/style.css`

Waybar replaces i3status with a CSS-themed status bar. Same data sources — disk, memory, CPU, load, time — but with proper theming support.

**Modules:** Workspaces (left), window title (center), system metrics + clock (right).

**Theme:** Mountain Twilight palette — matches sway and kitty. CSS in `style.css`, data in `config.json`. Edit either to customize.

### Rofi — Application Launcher

**File:** `configs/rofi/config.rasi`

Rofi replaces dmenu with a full GUI launcher: app launcher with icons, window switcher, and command runner. Fuzzy search, Vi navigation, fully themeable.

**Theme:** Mountain Twilight palette — matches sway and kitty. Amber gold selection highlight on deep navy background. 600px fixed width, 10 visible results, Papirus icon theme.

### Tmux — Terminal Multiplexer

**File:** `configs/tmux/tmux.conf`

Tmux and sway serve different purposes but use the same navigation keys — muscle memory transfers. Sway manages windows across the desktop; tmux manages terminal sessions within a single window.

**Vi mode** and **mouse** are enabled. The agent uses tmux's `send-keys` and `capture-pane` for programmatic access.

**Plugins (via TPM):**
- `tmux-yank` — sync clipboard with system
- `tmux-logging` — log pane output to file
- `tmux-gruvbox` — dark variant

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

This is a starting point. The important settings are `expandtab` (spaces, not tabs), `shiftwidth=4` (standard indent), and `clipboard=unnamedplus` (system clipboard integration — yank in vim, paste anywhere). Requires `vim-gtk3` — the plain `vim` package on Debian doesn't compile with clipboard support. On Wayland, vim-gtk3 auto-detects `wl-clipboard`.

### Bash — Shell

**File:** `configs/bash/bashrc`

Shi additions appended to your existing `.bashrc`:

```bash
export EDITOR=vim
export VISUAL=$EDITOR
set -o vi
```

`set -o vi` enables Vi-mode keybindings in bash. No `DISPLAY` variable needed — sway sets `WAYLAND_DISPLAY` automatically for all session processes.

---

## Keyboard Reference Card

### Global (Sway)

| Key | Action |
|-----|--------|
| `$mod+Return` | Open kitty |
| `$mod+q` | Close window |
| `$mod+d` | rofi app launcher |
| `$mod+Tab` | Sway window switcher (rofi dmenu) |
| `$mod+Shift+d` | rofi command runner |
| `$mod+grave` | Agent TUI toggle |
| `$mod+h/j/k/l` | Focus left/down/up/right |
| `$mod+Shift+h/j/k/l` | Move window |
| `$mod+1-0` | Switch workspace |
| `$mod+Shift+1-0` | Move to workspace |
| `$mod+v` | Split horizontal |
| `$mod+Shift+v` | Split vertical |
| `$mod+b` | Stacking layout |
| `$mod+w` | Tabbed layout |
| `$mod+e` | Toggle split |
| `$mod+f` | Fullscreen |
| `$mod+Shift+Space` | Toggle float |
| `$mod+Space` | Focus toggle (tiled ↔ floating) |
| `$mod+left-drag` | Move floating window |
| `$mod+right-drag` | Resize floating window |
| `$mod+r` | Enter resize mode |
| `$mod+Shift+r` | Reload config |
| `$mod+Shift+e` | Exit sway |
| `Print` | Screenshot |
| `$mod+Print` | Screenshot selection |

### Resize Mode (Sway, `$mod+r` to enter)

| Key | Action |
|-----|--------|
| `h/j/k/l` | 10px adjustment |
| `Shift+h/j/k/l` | 50px jump |
| `Arrow keys` | 10px adjustment |
| `Enter` / `Escape` | Exit mode |

### Tmux

| Key | Action |
|-----|--------|
| `Alt+h/j/k/l` | Switch pane |
| `Ctrl+b %` | Split horizontal |
| `Ctrl+b "` | Split vertical |
| `Ctrl+b c` | New window |
| `Ctrl+b n/p` | Next/prev window |
| `Ctrl+b [` | Copy mode (Vi) |
| `Ctrl+b z` | Zoom pane |

---

## Troubleshooting

### Sway: "Unable to find configuration file"

No config file exists. Copy from this repo:

```bash
cp configs/sway/config ~/.config/sway/config
```

### Kitty: Config not loading

`cursor_color` was renamed to `cursor` in kitty 0.41.1. Use `cursor` in kitty.conf.

### Kitty: Transparency not working

On Wayland, kitty transparency works natively — no compositor needed. Set `background_opacity` in kitty.conf or use sway's `for_window` opacity rule.

### Waybar: Not appearing

Check that `swaybar_command waybar` is in the sway config's `bar {}` block, and that waybar is installed:

```bash
which waybar
# If missing: sudo apt-get install waybar
```

### Waybar: Segfault on startup (Signal 11)

Waybar crashes with SEGV in `libsigc++` during D-Bus proxy initialization. This happens when `xdg-desktop-portal-wlr` is not installed — the portal falls back to GTK/KDE backends (which timeout in pure Sway), and waybar crashes connecting to the broken portal.

Fix:

```bash
# Install the missing portal backend
sudo apt-get install -y xdg-desktop-portal-wlr

# Create portal config (the install script does this automatically)
mkdir -p ~/.config/xdg-desktop-portal
cat > ~/.config/xdg-desktop-portal/portals.conf << 'EOF'
[preferred]
default=wlr;gtk
org.freedesktop.impl.portal.FileChooser=gtk
EOF
```

Then restart sway or reload the config.

### ydotool: "Connection refused"

The `ydotoold` daemon isn't running. Start it:

```bash
ydotoold &
```

The sway config starts it automatically. If it fails, check `journalctl --user -u ydotoold`.

### Browser tools: "Could not connect"

Chromium needs to run with CDP enabled:

```bash
chromium --remote-debugging-port=9222
```

Then set in Hermes:

```bash
hermes config set browser.cdp_url "http://localhost:9222"
```

### Screenshots: "grim: no output"

Grim needs a Wayland session. If running from SSH or a non-sway terminal, set:

```bash
export SWAYSOCK=/run/user/$(id -u)/sway-ipc.$(id -u).$(pgrep -x sway).sock
```

---

## Skills

The `skills/` directory contains Hermes Agent skills — procedural knowledge for desktop automation. These are loaded on demand, not all at once.

### Sway Desktop (`skills/sway-desktop/`)

Everything between the agent and the desktop: swaymsg window management, kitty remote control (`kitten @`), grim screenshots, wl-clipboard, swaybg wallpaper, and ydotool/wtype input simulation.

Load when: moving windows, launching apps, capturing the screen, reading the clipboard, or controlling kitty programmatically.

### Tmux (`skills/tmux/`)

Terminal multiplexer operations: send-keys, capture-pane, copy mode, session management, coordinate long-running work across panes.

Load when: working inside terminal sessions, watching builds, extracting text from scrollback, or coordinating parallel work.

### Installing Skills

```bash
# Copy to Hermes
cp -r skills/sway-desktop ~/.hermes/skills/
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
| **dunst** | Notification daemon | Sway has `mako` as a native alternative, but dunst works too. Without a notification daemon, system alerts are silently dropped. CLI-configurable via `dunstctl`. |
| **ranger** | Terminal file manager with Vi keys | Better than `ls`/`cd`/`cat` for browsing the filesystem. Image previews with kitty's icat protocol. |
| **htop** | Process monitor | Interactive `top` replacement with Vi-style navigation and tree view. |

### Notifications (mako or dunst)

Sway ships with `mako` as the recommended notification daemon. Install and add to sway config:

```bash
sudo apt-get install mako-notifier
```

```
exec --no-startup-id mako &
```

Or use dunst (works on Wayland too):

```bash
sudo apt-get install dunst
exec --no-startup-id dunst &
```

Test with:

```bash
notify-send "Shi" "Desktop notifications working"
```

---

## Customization

### Theming

All colors are defined as five variables at the top of the sway config. Change these and everything follows:

```
set $bg       #1a1a2e    # background
set $fg       #c8c8d4    # foreground text
set $accent   #c9a227    # highlights and focus
set $urgent   #c94427    # alerts
set $dim      #4a4a5e    # inactive elements
```

Match the kitty and waybar themes to the same palette. Waybar uses CSS in `configs/waybar/style.css`.

### Gaps

Sway has gaps built in (no separate package). Edit in sway config:

```
gaps inner 8
gaps outer 2
```

### Wallpaper

Replace `~/wallpapers/vestige-dark.png` and update the swaybg command in sway config:

```
exec --no-startup-id swaybg -i ~/wallpapers/your-wallpaper.png -m fill
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
