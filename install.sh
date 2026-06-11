#!/usr/bin/env bash
# Shi (勢) — Install script
# Installs desktop configs for the Shi environment on Debian.
#
# Idempotent: safe to run multiple times. Backups are only created when the
# existing config differs from what would be installed. Configs are only
# overwritten when the source has changed.
#
# WARNING: This script will overwrite configs for i3, kitty, picom, i3status,
# vim, and tmux (backups are created automatically for all of them). It appends
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
#   For i3/kitty/picom/i3status, restore from ~/.config/*/config.bak backups
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

log "Shi (勢) — Desktop environment install"
log "Working from: $SCRIPT_DIR"
echo ""

# --- check required packages ---
REQUIRED_PKGS=(i3 i3status kitty picom feh maim xdotool rofi xsel vim chromium)
MISSING=()
for pkg in "${REQUIRED_PKGS[@]}"; do
  command -v "$pkg" &>/dev/null || MISSING+=("$pkg")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  warn "Missing packages: ${MISSING[*]}"
  warn "Install with: sudo apt-get install -y ${MISSING[*]}"
  warn "(Note: for vim, install vim-gtk3 for clipboard support)"
  echo ""
fi

# --- i3: standalone config ---
mkdir -p "$HOME/.config/i3"
install_if_changed "$SCRIPT_DIR/configs/i3/config" "$HOME/.config/i3/config"
for script in rofi-agent.sh shi-toggle.sh; do
  if [ -f "$SCRIPT_DIR/configs/i3/$script" ]; then
    install_if_changed "$SCRIPT_DIR/configs/i3/$script" "$HOME/.config/i3/$script"
    chmod +x "$HOME/.config/i3/$script"
  fi
done

# --- kitty: standalone config ---
mkdir -p "$HOME/.config/kitty"
install_if_changed "$SCRIPT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

# --- picom: standalone config ---
mkdir -p "$HOME/.config/picom"
install_if_changed "$SCRIPT_DIR/configs/picom/picom.conf" "$HOME/.config/picom/picom.conf"

# --- i3status: standalone config ---
mkdir -p "$HOME/.config/i3status"
install_if_changed "$SCRIPT_DIR/configs/i3status/config" "$HOME/.config/i3status/config"

# --- wallpaper ---
mkdir -p "$HOME/wallpapers"
if [ -f "$SCRIPT_DIR/wallpapers/vestige-dark.png" ]; then
  install_if_changed "$SCRIPT_DIR/wallpapers/vestige-dark.png" "$HOME/wallpapers/vestige-dark.png"
fi

# --- bash: append shi block (idempotent) ---
append_block_once "$HOME/.bashrc" "# --- SHI BEGIN ---" < "$SCRIPT_DIR/configs/bash/bashrc"
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
echo "  i3 config:        ~/.config/i3/config"
echo "  kitty config:     ~/.config/kitty/kitty.conf"
echo "  picom config:     ~/.config/picom/picom.conf"
echo "  i3status config:  ~/.config/i3status/config"
echo "  vim config:       ~/.vimrc"
echo "  tmux config:      ~/.tmux.conf"
echo "  wallpaper:        ~/wallpapers/vestige-dark.png"
echo "  bash additions:   appended to ~/.bashrc"
echo "  agent scripts:    ~/.config/i3/rofi-agent.sh, ~/.config/i3/shi-toggle.sh"
echo ""
echo "  Backups (only created when configs differ):"
echo "    Standalone:  ~/.config/*/config.bak, ~/.config/kitty/kitty.conf.bak"
echo "    Additive:    ~/.vimrc.bak, ~/.tmux.conf.bak"
echo ""
echo "  Next steps:"
echo "    1. Start i3 (or log out and back in with i3 as your session)"
echo "    2. Launch tmux and press Prefix + I to install plugins"
echo "    3. Reload your shell: source ~/.bashrc"
echo ""
echo "  Uninstall:"
echo "    Remove the SHI marker block in ~/.bashrc (markers: # --- SHI BEGIN/END ---)"
echo "    Remove the SHI marker block in ~/.tmux.conf (markers: # --- SHI BEGIN/END ---)"
echo "    Remove the SHI marker block in ~/.vimrc (markers: \" --- SHI BEGIN/END ---)"
echo "    Restore backups: cp ~/.vimrc.bak ~/.vimrc && cp ~/.tmux.conf.bak ~/.tmux.conf"
echo "    Standalone configs: cp ~/.config/i3/config.bak ~/.config/i3/config (etc.)"
echo ""
log "Done."
