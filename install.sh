#!/usr/bin/env bash
# Shi (勢) — Install script
# Installs desktop configs for the Shi environment on Debian (Sway/Wayland).
#
# Idempotent: safe to run multiple times. Backups are only created when the
# existing config differs from what would be installed. Configs are only
# overwritten when the source has changed.
#
# WARNING: This script will overwrite configs for sway, kitty, waybar, vim,
# and tmux (backups are created automatically for all of them). It appends
# to ~/.bashrc idempotently (only if the SHI block is not already present).
#
# Back up your existing configs first if you care about them.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# Uninstall:
#   To remove SHI additions from bash/vim/tmux, delete the block between
#   "# --- SHI BEGIN ---" and "# --- SHI END ---" in each file.
#   For vim, the markers use " (Vim comment) instead of #.
#   For vim/tmux, restore from the .bak files created during install.
#   For sway/waybar/kitty, restore from ~/.config/*/config.bak backups
#   or reinstall the packages' defaults.

set -euo pipefail
IFS=$'\n\t'

# --- helpers ---
log(){ printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }

append_block_once(){ # append_block_once <file> <marker> < content from stdin
  local file="$1" marker="$2"
  grep -Fq "$marker" "$file" 2>/dev/null && { log "Block already present in $file"; return 0; }
  cat >>"$file"
  log "Added block to $file"
}

backup_if_differs(){ # backup_if_differs <source> <dest>
  local src="$1" dst="$2"
  [ -f "$dst" ] || return 0
  diff -q "$src" "$dst" >/dev/null 2>&1 && return 0
  cp "$dst" "${dst}.bak"
  log "Backed up $dst (differs from source)"
}

install_if_changed(){ # install_if_changed <source> <dest>
  local src="$1" dst="$2"
  if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
    log "$(basename "$dst") unchanged, skipping"
    return 0
  fi
  backup_if_differs "$src" "$dst"
  cp "$src" "$dst"
  log "Installed $dst"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- check we're not root ---
if [ "$(id -u)" -eq 0 ]; then
  echo "Don't run this as root. Run as your normal user."
  exit 1
fi

log "Shi (勢) — Desktop environment install (Sway/Wayland)"
log "Working from: $SCRIPT_DIR"
echo ""

# --- check required packages ---
# Map: package_name -> binary to check (where they differ)
declare -A PKG_BIN=(
  [wl-clipboard]=wl-copy
  [vim-gtk3]=vim
  [xdg-desktop-portal-wlr]=/usr/libexec/xdg-desktop-portal-wlr
)
REQUIRED_PKGS=(sway swaybg waybar grim slurp wl-clipboard ydotool rofi kitty vim-gtk3 chromium jq xdg-desktop-portal-wlr)
MISSING=()
for pkg in "${REQUIRED_PKGS[@]}"; do
  bin="${PKG_BIN[$pkg]:-$pkg}"
  command -v "$bin" &>/dev/null || MISSING+=("$pkg")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  warn "Missing packages: ${MISSING[*]}"
  warn "Install with: sudo apt-get install -y ${MISSING[*]}"
  warn "(Note: on some distros, rofi is packaged as rofi-wayland)"
  echo ""
fi

# --- sway: standalone config ---
mkdir -p "$HOME/.config/sway"
install_if_changed "$SCRIPT_DIR/configs/sway/config" "$HOME/.config/sway/config"
for script in shi-toggle.sh sway-window-switcher.sh; do
  if [ -f "$SCRIPT_DIR/configs/sway/$script" ]; then
    install_if_changed "$SCRIPT_DIR/configs/sway/$script" "$HOME/.config/sway/$script"
    chmod +x "$HOME/.config/sway/$script"
  fi
done

# --- kitty: standalone config ---
mkdir -p "$HOME/.config/kitty"
install_if_changed "$SCRIPT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# --- waybar: standalone config + style ---
mkdir -p "$HOME/.config/waybar"
install_if_changed "$SCRIPT_DIR/configs/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
install_if_changed "$SCRIPT_DIR/configs/waybar/style.css" "$HOME/.config/waybar/style.css"

# --- xdg-desktop-portal config (prevents waybar SEGV with greetd) ---
PORTALS_DIR="$HOME/.config/xdg-desktop-portal"
PORTALS_CONF="$PORTALS_DIR/portals.conf"
if [ ! -f "$PORTALS_CONF" ]; then
  mkdir -p "$PORTALS_DIR"
  printf '[preferred]\ndefault=wlr;gtk\norg.freedesktop.impl.portal.FileChooser=gtk\n' > "$PORTALS_CONF"
  log "Installed $PORTALS_CONF"
else
  log "portals.conf already present, skipping"
fi

# --- wallpaper ---
mkdir -p "$HOME/wallpapers"
if [ -f "$SCRIPT_DIR/wallpapers/vestige-dark.png" ]; then
  install_if_changed "$SCRIPT_DIR/wallpapers/vestige-dark.png" "$HOME/wallpapers/vestige-dark.png"
fi

# --- bash: replace shi block if it exists, or append ---
BASHRC="$HOME/.bashrc"
if grep -Fq "# --- SHI BEGIN ---" "$BASHRC" 2>/dev/null; then
  # Block exists — check if it needs updating (e.g. old DISPLAY=:0)
  if grep -q 'DISPLAY=:0' "$BASHRC"; then
    log "Updating bash SHI block (removing deprecated DISPLAY=:0)..."
    # Replace the entire SHI block
    python3 -c "
import re, sys
with open('$BASHRC', 'r') as f:
    content = f.read()
new_block = open('$SCRIPT_DIR/configs/bash/bashrc').read().strip()
pattern = r'# --- SHI BEGIN ---.*?# --- SHI END ---'
content = re.sub(pattern, new_block, content, flags=re.DOTALL)
with open('$BASHRC', 'w') as f:
    f.write(content)
"
    log "Bash SHI block updated"
  else
    log "Bash SHI block already present and up to date"
  fi
else
  append_block_once "$BASHRC" "# --- SHI BEGIN ---" < "$SCRIPT_DIR/configs/bash/bashrc"
fi
log "Bash additions applied"

# --- vim: additive config with markers ---
install_if_changed "$SCRIPT_DIR/configs/vim/vimrc" "$HOME/.vimrc"

# --- tmux: additive config with markers ---
install_if_changed "$SCRIPT_DIR/configs/tmux/tmux.conf" "$HOME/.tmux.conf"

# --- TPM bootstrap ---
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  log "Installing TPM (tmux plugin manager)…"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  log "TPM installed"
else
  log "TPM already present"
fi

# --- Hermes skills (if Hermes is installed) ---
HERMES_SKILLS_DIR="$HOME/.hermes/skills"
if [ -d "$HOME/.hermes" ] && [ -d "$SCRIPT_DIR/skills" ]; then
  for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$HERMES_SKILLS_DIR/$skill_name"
    for file in "$skill_dir"*; do
      install_if_changed "$file" "$HERMES_SKILLS_DIR/$skill_name/$(basename "$file")"
    done
  done
elif [ -d "$SCRIPT_DIR/skills" ]; then
  log "Hermes not found at ~/.hermes — skills not installed (copy manually)"
fi

# --- summary ---
echo ""
log "Install complete."
echo ""
echo "  sway config:      ~/.config/sway/config"
echo "  kitty config:     ~/.config/kitty/kitty.conf"
echo "  waybar config:    ~/.config/waybar/config.jsonc"
echo "  waybar style:     ~/.config/waybar/style.css"
echo "  portal config:    ~/.config/xdg-desktop-portal/portals.conf"
echo "  vim config:       ~/.vimrc"
echo "  tmux config:      ~/.tmux.conf"
echo "  wallpaper:        ~/wallpapers/vestige-dark.png"
echo "  bash additions:   appended to ~/.bashrc"
echo "  agent scripts:    ~/.config/sway/shi-toggle.sh, sway-window-switcher.sh"
echo ""
echo "  Backups (only created when configs differ):"
echo "    Standalone:  ~/.config/*/config.bak, ~/.config/kitty/kitty.conf.bak"
echo "    Portal:      rm ~/.config/xdg-desktop-portal/portals.conf"
echo "    Additive:    ~/.vimrc.bak, ~/.tmux.conf.bak"
echo ""
echo "  Next steps:"
echo "    1. Log out and start a Sway session (or run 'sway' from TTY)"
echo "    2. Launch tmux and press Prefix + I to install plugins"
echo "    3. Reload your shell: source ~/.bashrc"
echo ""
echo "  Uninstall:"
echo "    Remove the SHI marker block in ~/.bashrc (markers: # --- SHI BEGIN/END ---)"
echo "    Remove the SHI marker block in ~/.tmux.conf (markers: # --- SHI BEGIN/END ---)"
echo "    Remove the SHI marker block in ~/.vimrc (markers: \" --- SHI BEGIN/END ---)"
echo "    Restore backups: cp ~/.vimrc.bak ~/.vimrc && cp ~/.tmux.conf.bak ~/.tmux.conf"
echo "    Standalone configs: cp ~/.config/sway/config.bak ~/.config/sway/config (etc.)"
echo ""
log "Done."
