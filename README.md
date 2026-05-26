# Ricing Your Rig with Hermes Agent

A complete guide to building a CLI-controllable, Vi-driven desktop environment on Debian, designed for humans and AI agents to share.

**What you get:**
- i3 tiling window manager with Vi-style navigation
- Kitty terminal with remote control (agent can drive it)
- Picom compositor for transparency and effects
- PipeWire audio stack
- Chromium with CDP for browser automation
- Everything controllable from the command line

**What you need:**
- Debian 12+ (tested on Trixie/13)
- A display (monitor, not headless)
- Sudo access
- ~30 minutes

---

## Philosophy

This isn't about making your desktop look pretty (though it does). It's about building a workspace where both you and an AI agent can operate — moving windows, launching programs, reading screens, taking screenshots — all through CLI tools.

Every tool here has a command-line interface. Every keybinding follows Vi conventions. The agent doesn't need to fake mouse clicks or guess at screen coordinates — it talks to i3, kitty, and Chromium through their native IPC protocols.

**Design principles:**
1. **CLI-first** — if you can't control it from the terminal, it doesn't belong here
2. **Vi keys everywhere** — h/j/k/l for navigation in i3, tmux, vim, resize mode
3. **Agent-transparent** — the agent can see, control, and automate every layer
4. **Minimal dependencies** — nothing heavy, nothing that needs a full desktop environment
5. **Persistent** — everything auto-starts on login, survives reboots

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                    i3                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  kitty   │  │  kitty   │  │ chromium  │  │
│  │  + tmux  │  │  + bash  │  │  (CDP)   │  │
│  └──────────┘  └──────────┘  └──────────┘  │
│  ┌──────────────────────────────────────┐   │
│  │            i3bar (top)               │   │
│  └──────────────────────────────────────┘   │
├─────────────────────────────────────────────┤
│  PipeWire  │  Picom  │  feh (wallpaper)    │
└─────────────────────────────────────────────┘
```

**Control stack:**
| Layer | CLI Tool | Agent Access |
|-------|----------|--------------|
| Window manager | `i3-msg` | `DISPLAY=:0 i3-msg` |
| Terminal | `kitten @` | Via Unix socket |
| Browser | CDP (port 9222) | `browser_*` tools |
| Screenshots | `maim` | `DISPLAY=:0 maim` |
| Keyboard/mouse | `xdotool` | `DISPLAY=:0 xdotool` |
| Audio | `wpctl` | Direct CLI |

---

## Installation

### 1. Core Packages

```bash
sudo apt-get install -y \
  i3 i3status i3lock dmenu \
  kitty \
  picom \
  feh \
  maim xdotool \
  pipewire wireplumber pipewire-alsa pipewire-pulse \
  alsa-utils \
  portaudio19-dev \
  chromium lightdm
```

**Why these:**
- **i3** — tiling WM, scriptable via `i3-msg`, Vi-native navigation
- **kitty** — GPU-accelerated terminal with remote control protocol (`kitten @`)
- **picom** — compositor for transparency, shadows, blur
- **feh** — lightweight wallpaper setter
- **maim** — modern screenshot tool (replaces `scrot`)
- **xdotool** — X11 automation (send keystrokes, move windows)
- **pipewire** — modern audio server with ALSA resampling
- **portaudio19-dev** — C library that `sounddevice` (Python) wraps
- **chromium** — browser with CDP for agent automation
- **lightdm** — display manager with autologin

### 2. Audio Stack

PipeWire replaces PulseAudio and ALSA as the audio server. The key package is `pipewire-alsa` — it creates a virtual ALSA device that routes through PipeWire, handling sample rate conversion automatically. Without it, USB microphones that only support 44.1/48kHz will fail when voice mode requests 16kHz.

```bash
# Enable user services
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

Verify:
```bash
wpctl status
# Should show your audio devices with defaults marked (*)
```

### 3. Display Manager

Configure LightDM for autologin:

```bash
sudo tee -a /etc/lightdm/lightdm.conf << 'EOF'

[Seat:*]
user-session=i3
autologin-user=yourusername
EOF

sudo systemctl enable lightdm
```

### 4. Install the Configs

```bash
# Clone this repo
git clone https://github.com/YOURUSER/ricing-your-rig.git
cd ricing-your-rig

# i3
mkdir -p ~/.config/i3
cp configs/i3/config ~/.config/i3/config

# Kitty
mkdir -p ~/.config/kitty
cp configs/kitty/kitty.conf ~/.config/kitty/kitty.conf

# Picom
mkdir -p ~/.config/picom
cp configs/picom/picom.conf ~/.config/picom/picom.conf

# i3status
mkdir -p ~/.config/i3status
cp configs/i3status/config ~/.config/i3status/config

# Tmux
cp configs/tmux/tmux.conf ~/.tmux.conf

# Vim
cp configs/vim/vimrc ~/.vimrc

# Wallpaper
mkdir -p ~/wallpapers
cp wallpapers/vestige-dark.png ~/wallpapers/

# Bash additions (append, don't overwrite)
cat configs/bash/bashrc >> ~/.bashrc

# Reload i3
i3-msg reload
```

### 5. Hermes Agent Integration

If you're running Hermes Agent, add the display environment and browser CDP:

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

**Navigation (Vi-style):**
```
$h/j/k/l$     — focus windows (left/down/up/right)
$+Shift+h/j/k/l$ — move windows
$+1-0$        — switch workspaces
$+Shift+1-0$  — move window to workspace
```

**Why $mod (Super) instead of Alt:** Alt conflicts with terminal applications (tmux, vim). Super is unused by most terminal tools and sits comfortably under the left thumb.

**Resize mode:**
```
$r$            — enter resize mode
h/j/k/l       — 10px adjustments
Shift+h/j/k/l — 50px jumps
Enter/Escape  — exit
```

**Floating windows:**
```
$+Shift+Space$ — toggle float
$+Space$       — focus toggle (tiled ↔ floating)
$+left-drag$   — move floating window
$+right-drag$  — resize floating window
```

The `floating_modifier $mod` directive enables mouse-based move/resize on floating windows. Without it, you can only resize via keyboard.

**Bar:** Top-positioned, themed to match the color scheme. `i3status` feeds it system metrics.

**Autostart:** Picom (compositor), feh (wallpaper), kitty (terminal), and Chromium (browser with CDP) all launch automatically.

### Kitty — Terminal

**File:** `configs/kitty/kitty.conf`

Kitty is chosen over alacritty/urxvt for one reason: **remote control**. The `kitten @` protocol lets the agent send commands, read terminal contents, and manage windows without faking keystrokes.

**Key settings:**
```
allow_remote_control yes
listen_on unix:/tmp/kitty-ipc
```

The socket has a PID suffix (`/tmp/kitty-ipc-{PID}`). Discover it with:
```bash
ls -t /tmp/kitty-ipc-* | head -1
```

**Agent commands:**
```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
kitten @ --to unix:$SOCK ls                    # list windows
kitten @ --to unix:$SOCK send-text --match id:1 'command\n'
kitten @ --to unix:$SOCK launch --type=window htop
kitten @ --to unix:$SOCK get-text --match id:1
kitten @ --to unix:$SOCK close-window --match id:2
```

**Theme:** Mountain Twilight — deep navy backgrounds (`#1a1a2e`), muted silver text, amber gold accents. 95% opacity with picom blur behind.

**Cursor:** `cursor #c9a227` (amber). Note: kitty 0.41.1 renamed `cursor_color` to `cursor`.

### Picom — Compositor

**File:** `configs/picom/picom.conf`

Picom adds the visual layer: transparency, blur, shadows, fading. Without it, kitty's `background_opacity` setting is silently ignored.

**Key effects:**
- **Transparency:** Focused kitty at 90%, unfocused at 80%. Chromium stays at 100%.
- **Blur:** `dual_kawase` at strength 3 — frosted glass behind transparent windows
- **Shadows:** 12px radius, 0.6 opacity — subtle depth
- **Fading:** 0.03 step transitions — smooth but not slow

**Backend:** `glx` with vsync. If you get tearing, try `xrender`.

**Why picom over compton:** Compton is dead. Picom is its actively-maintained fork. xcompmgr is too minimal.

### i3status — Bar

**File:** `configs/i3status/config`

Clean text labels instead of Nerd Font icons. Icons require a patched Nerd Font and break when the font doesn't have the glyphs. Plain text is universal.

```
Disk: 42G
Mem: 2.3G / 15.5G
CPU: 4%
Load: 0.42
Mon 26 May 07:15
```

Colors: green (good), amber (degraded), rust red (critical).

### Tmux — Terminal Multiplexer

**File:** `configs/tmux/tmux.conf`

Tmux and i3 serve different purposes but use the same navigation keys. This is intentional — muscle memory transfers.

**i3 manages windows.** Tmux manages terminal sessions within a single window.

**Navigation (same keys as i3):**
```
Alt+h/j/k/l — switch panes (no prefix needed)
```

**Vi mode:**
```
set-window-option -g mode-keys vi
```

This enables Vi-style copy mode: `Space` to start selection, `h/j/k/l` to navigate, `Enter` to copy.

**Mouse:** Enabled (`set -g mouse on`) for pane resizing and scrollback. The agent uses tmux's `send-keys` and `capture-pane` for programmatic access.

**Plugins (via TPM):**
- `tmux-yank` — sync clipboard with system
- `tmux-logging` — log pane output to file
- `tmux-gruvbox` — dark theme

### Vim — Editor

**File:** `configs/vim/vimrc`

Minimal config focused on code editing:
```
set nocompatible
filetype on
filetype indent on
syntax on
set number
set autoindent expandtab tabstop=4 shiftwidth=4
```

**Why so minimal:** Vim config is personal. This is a starting point. The important thing is `expandtab` (spaces, not tabs) and `shiftwidth=4` (standard indent).

### Bash — Shell

**File:** `configs/bash/bashrc`

Standard Debian `.bashrc` with one addition for agent X11 access:

```bash
# X display for i3 agent control
export DISPLAY=:0
```

This lets any new terminal shell access the X server. Without it, tools like `i3-msg`, `xdotool`, and `kitten @` can't find the display.

---

## Agent Control Reference

### i3 Window Manager
```bash
DISPLAY=:0 i3-msg reload                    # reload config
DISPLAY=:0 i3-msg 'workspace 2'            # switch workspace
DISPLAY=:0 i3-msg '[class="kitty"] kill'   # close all kitty windows
DISPLAY=:0 i3-msg -t get_tree              # full window tree (JSON)
DISPLAY=:0 i3-msg -t get_outputs           # monitor info
```

### Kitty Terminal
```bash
SOCK=$(ls -t /tmp/kitty-ipc-* | head -1)
kitten @ --to unix:$SOCK ls                # list all windows
kitten @ --to unix:$SOCK send-text --match id:1 'echo hello\n'
kitten @ --to unix:$SOCK get-text --match id:1
kitten @ --to unix:$SOCK launch --type=window htop
kitten @ --to unix:$SOCK close-window --match id:2
```

### Browser (CDP)
```bash
curl -s http://localhost:9222/json/version  # verify CDP
curl -s http://localhost:9222/json          # list tabs
# Or use Hermes browser_* tools directly
```

### Screenshots
```bash
DISPLAY=:0 maim ~/shot.png                  # full screen
DISPLAY=:0 maim -s ~/shot.png              # selection
DISPLAY=:0 maim -i WINDOW_ID ~/shot.png    # specific window
```

### Audio
```bash
wpctl status                               # show devices
wpctl set-volume 48 0.8                    # set sink volume
wpctl set-default-sink 48                  # set default output
wpctl set-default-source 49                # set default input
```

### Tmux
```bash
tmux list-panes -a                         # list all panes
tmux capture-pane -p -J -t %0 -S -100     # capture pane output
tmux send-keys -t %0 'command' Enter      # send command to pane
tmux new-session -d -s build               # new named session
```

---

## Keyboard Reference Card

### i3 (Global)
| Key | Action |
|-----|--------|
| `$mod+Return` | Open kitty |
| `$mod+q` | Close window |
| `$mod+d` | dmenu launcher |
| `$mod+h/j/k/l` | Focus left/down/up/right |
| `$mod+Shift+h/j/k/l` | Move window |
| `$mod+1-0` | Switch workspace |
| `$mod+Shift+1-0` | Move to workspace |
| `$mod+v` | Split horizontal |
| `$mod+Shift+v` | Split vertical |
| `$mod+f` | Fullscreen |
| `$mod+Shift+Space` | Toggle float |
| `$mod+Space` | Focus toggle |
| `$mod+r` | Resize mode |
| `$mod+Shift+r` | Reload config |
| `$mod+Shift+e` | Exit i3 |
| `Print` | Screenshot |
| `$mod+Print` | Screenshot selection |

### Tmux (Inside Terminal)
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
| `Enter/Escape` | Exit mode |

---

## Troubleshooting

### Audio: "Invalid sample rate" in voice mode
**Cause:** Raw ALSA device doesn't support the requested sample rate.
**Fix:** Install `pipewire-alsa` and restart the Hermes session. The new `default` device handles resampling.

### Kitty: Config not loading
**Cause:** `cursor_color` renamed to `cursor` in kitty 0.41.1.
**Fix:** Use `cursor` in kitty.conf.

### Kitty: Transparency not working
**Cause:** No compositor running.
**Fix:** Start picom. Without it, `background_opacity` is silently ignored.

### i3: "Unable to find configuration file"
**Cause:** No config file exists.
**Fix:** Copy the config from this repo to `~/.config/i3/config`.

### LightDM: Login loop
**Cause:** `/var/run/utmpx` missing (common on minimal/container installs).
**Fix:** `sudo touch /var/run/utmpx && sudo chmod 644 /var/run/utmpx`

### i3status: Broken icons in bar
**Cause:** Nerd Font glyphs in i3status config, but the font doesn't have them.
**Fix:** Use plain text labels (see `configs/i3status/config`).

### Browser tools: "Could not connect"
**Cause:** Chromium not running with CDP, or wrong `cdp_url`.
**Fix:** Launch with `--remote-debugging-port=9222` and set `hermes config set browser.cdp_url "http://localhost:9222"`

### Agent can't access X11
**Cause:** No `DISPLAY` variable set in the terminal session.
**Fix:** Add `export DISPLAY=:0` to `.bashrc` and run `xhost +local:`.

---

## Customization

### Changing the Theme

All colors are defined as variables at the top of the i3 config:
```
set $bg       #1a1a2e
set $fg       #c8c8d4
set $accent   #c9a227
set $urgent   #c94427
set $dim      #4a4a5e
```

Change these five values and the entire desktop rethemes — i3 bar, dmenu, window decorations.

Match the kitty theme to the same palette in `~/.config/kitty/kitty.conf`.

### Adding Gaps

If you install `i3-gaps`:
```
gaps inner 8
gaps outer 2
```

### Different Wallpaper

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

This is a living document. If you find a better way to do something, a missing step, or a broken command — open an issue or PR.

Config files in `configs/` are the source of truth. The README explains why.

---

## License

MIT. Do whatever you want with it.
