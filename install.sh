#!/usr/bin/env bash
# Shi (勢) — Install script
# Installs desktop configs for the Shi environment on Debian.
#
# WARNING: This script will overwrite ~/.vimrc and ~/.tmux.conf (backups are
# created automatically). It appends to ~/.bashrc idempotently (only if the
# SHI block is not already present). Standalone configs (i3, kitty, picom,
# i3status) are copied to ~/.config/.
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
#   For vim/tmux, restore from the .bak files created during install.
#   For i3/kitty/picom/i3status, restore your previous configs from
#   ~/.config/*/bak.* backups or reinstall the packages' defaults.

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
REQUIRED_PKGS=(i3 i3status kitty picom feh maim xdotool xsel vim chromium)
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

# --- i3: standalone config, copy as-is ---
mkdir -p "$HOME/.config/i3"
cp "$SCRIPT_DIR/configs/i3/config" "$HOME/.config/i3/config"
log "Installed i3 config"

# --- kitty: standalone config, copy as-is ---
mkdir -p "$HOME/.config/kitty"
cp "$SCRIPT_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
log "Installed kitty config"

# --- picom: standalone config, copy as-is ---
mkdir -p "$HOME/.config/picom"
cp "$SCRIPT_DIR/configs/picom/picom.conf" "$HOME/.config/picom/picom.conf"
log "Installed picom config"

# --- i3status: standalone config, copy as-is ---
mkdir -p "$HOME/.config/i3status"
cp "$SCRIPT_DIR/configs/i3status/config" "$HOME/.config/i3status/config"
log "Installed i3status config"

# --- wallpaper ---
mkdir -p "$HOME/wallpapers"
if [ -f "$SCRIPT_DIR/wallpapers/vestige-dark.png" ]; then
  cp "$SCRIPT_DIR/wallpapers/vestige-dark.png" "$HOME/wallpapers/"
  log "Installed wallpaper"
fi

# --- bash: append shi block (idempotent) ---
append_block_once "$HOME/.bashrc" "# --- SHI BEGIN ---" < "$SCRIPT_DIR/configs/bash/bashrc"
log "Bash additions applied"

# --- vim: backup existing, then copy ---
if [ -f "$HOME/.vimrc" ]; then
  cp "$HOME/.vimrc" "$HOME/.vimrc.bak"
  log "Backed up existing ~/.vimrc to ~/.vimrc.bak"
fi
cp "$SCRIPT_DIR/configs/vim/vimrc" "$HOME/.vimrc"
log "Installed ~/.vimrc"

# --- tmux: backup existing, then copy ---
if [ -f "$HOME/.tmux.conf" ]; then
  cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
  log "Backed up existing ~/.tmux.conf to ~/.tmux.conf.bak"
fi
cp "$SCRIPT_DIR/configs/tmux/tmux.conf" "$HOME/.tmux.conf"
log "Installed ~/.tmux.conf"

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
    cp "$skill_dir"/* "$HERMES_SKILLS_DIR/$skill_name/"
    log "Installed Hermes skill: $skill_name"
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
echo ""
echo "  Backups:          ~/.vimrc.bak, ~/.tmux.conf.bak"
echo ""
echo "  Next steps:"
echo "    1. Start i3 (or log out and back in with i3 as your session)"
echo "    2. Launch tmux and press Prefix + I to install plugins"
echo "    3. Reload your shell: source ~/.bashrc"
echo ""
echo "  Uninstall:"
echo "    Remove the block between '# --- SHI BEGIN ---' and '# --- SHI END ---'"
echo "    in ~/.bashrc, ~/.vimrc, and ~/.tmux.conf."
echo "    Restore backups: cp ~/.vimrc.bak ~/.vimrc && cp ~/.tmux.conf.bak ~/.tmux.conf"
echo ""
log "Done."
